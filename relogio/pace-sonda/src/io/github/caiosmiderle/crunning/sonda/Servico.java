package io.github.caiosmiderle.crunning.sonda;

import android.app.Notification;
import android.app.Service;
import android.content.Intent;
import android.content.IntentFilter;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.location.GpsSatellite;
import android.location.GpsStatus;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.BatteryManager;
import android.os.Bundle;
import android.os.Environment;
import android.os.Handler;
import android.os.IBinder;
import android.os.PowerManager;
import android.os.SystemClock;

import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.Locale;

/**
 * Serviço em primeiro plano que lê o sensor de batimento e o GPS e grava, uma linha por
 * segundo, um CSV em /sdcard/CRUNNING-sonda. Não grava latitude nem longitude: só se havia
 * sinal, a precisão, a velocidade, os satélites, a distância e os ritmos, para medir se o
 * app sobrevive com a tela apagada sem guardar por onde você correu.
 */
public class Servico extends Service implements SensorEventListener, LocationListener {
    // Estado lido pela tela (mesmo processo).
    static volatile boolean rodando;
    static volatile long inicio;
    static volatile int bpm;
    static volatile long bpmEm;
    static volatile int leiturasFC;
    static volatile int leiturasGPS;
    static volatile long gpsEm;
    static volatile long gpsBomEm;
    static volatile float precisao;
    static volatile float precisaoBoa;
    static volatile double distanciaM;
    static volatile double paceAtual = -1;
    static volatile double paceMedio = -1;
    static volatile long tempoGravadoMs;
    static volatile int satelitesUsados;
    static volatile int satelitesVistos;
    static volatile int bateria = -1;
    static volatile boolean telaVisivel;
    static volatile String arquivo = "";

    private SensorManager sensores;
    private LocationManager local;
    private PowerManager energia;
    private PowerManager.WakeLock trava;
    private Handler handler;
    private PrintWriter log;
    private GpsStatus.Listener ouvinteGps;
    private float velocidade;
    private final IntentFilter filtroBateria = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);

    private static final long JANELA_MS = 12000;
    private static final long SEM_GPS_MS = 3000;
    private static final float PRECISAO_MAX_M = 25;
    private static final float VELOCIDADE_MAX_MPS = 12; // 43,2 km/h: rejeita saltos de corrida.
    private static final double VELOCIDADE_MIN_MPS = 1.0 / 3.6;
    // Só um ponto anterior em RAM. O histórico contém velocidades/tempos, nunca a rota.
    private final Location anterior = new Location(LocationManager.GPS_PROVIDER);
    private boolean temAnterior;
    private long anteriorEm;
    private long ultimaAmostraEm;
    private final long[] trechosInicio = new long[32];
    private final long[] trechosFim = new long[32];
    private final double[] trechosVelocidade = new double[32];
    private int proximoTrecho;
    private int quantidadeTrechos;

    private final Runnable tique = new Runnable() {
        @Override
        public void run() {
            if (!rodando) return;
            atualizarMetricas(SystemClock.elapsedRealtime());
            gravarLinha();
            handler.postDelayed(this, 1000);
        }
    };

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (rodando) return START_STICKY;
        rodando = true;
        inicio = SystemClock.elapsedRealtime();
        bpm = 0;
        bpmEm = 0;
        leiturasFC = 0;
        leiturasGPS = 0;
        gpsEm = 0;
        gpsBomEm = 0;
        precisao = -1;
        precisaoBoa = -1;
        velocidade = -1;
        satelitesUsados = 0;
        satelitesVistos = 0;
        bateria = -1;
        distanciaM = 0;
        paceAtual = -1;
        paceMedio = -1;
        tempoGravadoMs = 0;
        arquivo = "";
        temAnterior = false;
        ultimaAmostraEm = 0;
        limparJanela();

        Notification aviso = new Notification.Builder(this)
                .setContentTitle("CRUNNING sonda")
                .setContentText("Gravando batimento e GPS")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setOngoing(true)
                .build();
        startForeground(1, aviso);

        abrirLog();
        // Intent nulo = o sistema matou o processo e recriou o serviço (START_STICKY).
        evento(intent == null ? "inicio (recriado pelo sistema)" : "inicio");

        energia = (PowerManager) getSystemService(POWER_SERVICE);
        if (energia != null) {
            try {
                trava = energia.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "crunning:sonda");
                trava.acquire();
            } catch (SecurityException e) {
                evento("wake lock indisponivel");
            }
        } else {
            evento("sem gerenciador de energia");
        }

        sensores = (SensorManager) getSystemService(SENSOR_SERVICE);
        try {
            Sensor fc = sensores == null ? null : sensores.getDefaultSensor(Sensor.TYPE_HEART_RATE);
            if (fc != null) {
                boolean registrado = sensores.registerListener(this, fc, SensorManager.SENSOR_DELAY_NORMAL);
                evento(registrado ? "sensor de FC: " + fc.getName() + " / " + fc.getVendor()
                        : "falha ao registrar sensor de FC");
            } else {
                evento("sem sensor de FC");
            }
        } catch (SecurityException e) {
            evento("sensor de FC sem permissao");
        }

        local = (LocationManager) getSystemService(LOCATION_SERVICE);
        try {
            if (local != null) {
                local.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000, 0, this);
                ouvinteGps = new GpsStatus.Listener() {
                    @Override
                    public void onGpsStatusChanged(int qual) {
                        if (qual == GpsStatus.GPS_EVENT_SATELLITE_STATUS) contarSatelites();
                    }
                };
                local.addGpsStatusListener(ouvinteGps);
            } else {
                evento("sem gerenciador de GPS");
            }
        } catch (SecurityException | IllegalArgumentException e) {
            // Não serializar exceções/Location: podem conter dados do provedor.
            evento("gps indisponivel");
        }

        handler = new Handler();
        handler.post(tique);
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        atualizarMetricas(SystemClock.elapsedRealtime());
        evento("fim");
        rodando = false;
        if (handler != null) handler.removeCallbacks(tique);
        if (sensores != null) sensores.unregisterListener(this);
        if (local != null) {
            try {
                local.removeUpdates(this);
                if (ouvinteGps != null) local.removeGpsStatusListener(ouvinteGps);
            } catch (SecurityException e) {
                evento("gps sem permissao ao encerrar");
            }
        }
        if (trava != null && trava.isHeld()) trava.release();
        stopForeground(true);
        if (log != null) {
            log.close();
            log = null;
        }
        gpsBomEm = 0;
        paceAtual = -1;
        temAnterior = false;
        anterior.reset(); // Descarta o único ponto transitório também ao parar.
        limparJanela();
        super.onDestroy();
    }

    @Override
    public void onTrimMemory(int nivel) {
        evento("trimMemory " + nivel);
        super.onTrimMemory(nivel);
    }

    @Override
    public void onLowMemory() {
        evento("lowMemory");
        super.onLowMemory();
    }

    // MARK: Sensores

    @Override
    public void onSensorChanged(SensorEvent e) {
        if (!rodando || e == null || e.sensor == null || e.values == null
                || e.sensor.getType() != Sensor.TYPE_HEART_RATE || e.values.length == 0) return;
        int valor = Math.round(e.values[0]);
        if (valor < 30 || valor > 230) return;
        bpm = valor;
        bpmEm = SystemClock.elapsedRealtime();
        leiturasFC++;
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int precisaoSensor) {
        evento("precisao do sensor de FC: " + precisaoSensor);
    }

    @Override
    public void onLocationChanged(Location l) {
        if (!rodando || l == null) return;
        long agora = SystemClock.elapsedRealtime();
        gpsEm = agora;
        precisao = l.hasAccuracy() ? l.getAccuracy() : -1;
        velocidade = l.hasSpeed() ? l.getSpeed() : -1;
        leiturasGPS++;

        // API 17: relógio monotônico da própria amostra, não o horário civil ou de chegada.
        long amostraEm = l.getElapsedRealtimeNanos() / 1000000L;
        if (amostraEm < inicio || amostraEm <= ultimaAmostraEm || amostraEm > agora
                || agora - amostraEm > SEM_GPS_MS) return;
        ultimaAmostraEm = amostraEm;
        if (!finito(precisao) || precisao < 0 || precisao > PRECISAO_MAX_M
                || (l.hasSpeed() && (!finito(velocidade) || velocidade < 0
                || velocidade > VELOCIDADE_MAX_MPS))) {
            perderReferencia();
            return;
        }
        if (!temAnterior || amostraEm - anteriorEm > SEM_GPS_MS) {
            limparJanela();
            guardarReferencia(l, amostraEm);
            gpsBomEm = amostraEm;
            return;
        }
        long intervaloMs = amostraEm - anteriorEm;
        if (intervaloMs < 500) return; // Duplicatas/rajadas não dominam a janela de 12 s.
        float metros = anterior.distanceTo(l);
        double segundos = intervaloMs / 1000.0;
        if (!finito(metros) || metros < 0 || metros / segundos > VELOCIDADE_MAX_MPS) {
            // Não promove um salto a referência: voltar dele não deve contar outra distância.
            gpsBomEm = 0;
            limparJanela();
            return;
        }
        // Com velocidade GNSS de repouso, não acumula a deriva pequena das coordenadas.
        if (l.hasSpeed() && velocidade < VELOCIDADE_MIN_MPS) metros = 0;
        distanciaM += metros;
        trechosInicio[proximoTrecho] = anteriorEm;
        trechosFim[proximoTrecho] = amostraEm;
        trechosVelocidade[proximoTrecho] = l.hasSpeed() ? velocidade : metros / segundos;
        proximoTrecho = (proximoTrecho + 1) % trechosInicio.length;
        quantidadeTrechos = Math.min(quantidadeTrechos + 1, trechosInicio.length);
        guardarReferencia(l, amostraEm);
        gpsBomEm = amostraEm;
    }

    private static boolean finito(float valor) {
        return !Float.isNaN(valor) && !Float.isInfinite(valor);
    }

    private void guardarReferencia(Location l, long em) {
        anterior.set(l);
        anteriorEm = em;
        precisaoBoa = l.getAccuracy();
        temAnterior = true;
    }

    private void limparJanela() {
        quantidadeTrechos = 0;
        proximoTrecho = 0;
        paceAtual = -1;
    }

    private void perderReferencia() {
        gpsBomEm = 0;
        temAnterior = false;
        anterior.reset();
        limparJanela();
    }

    private void atualizarMetricas(long agora) {
        tempoGravadoMs = Math.max(0, agora - inicio);
        paceMedio = distanciaM >= 1 ? tempoGravadoMs / distanciaM : -1;
        // ms / m tem o mesmo valor numérico que s / km.
        paceAtual = -1;
        if (gpsBomEm <= 0) {
            // Um salto isolado esconde o ritmo, mas preserva o ponto bom por até 3 s.
            if (temAnterior && agora - anteriorEm > SEM_GPS_MS) perderReferencia();
            return;
        }
        if (agora - gpsBomEm > SEM_GPS_MS) {
            perderReferencia();
            return;
        }
        double metrosJanela = 0;
        long duracaoMs = 0;
        for (int i = 0; i < quantidadeTrechos; i++) {
            long de = Math.max(trechosInicio[i], agora - JANELA_MS);
            long ate = Math.min(trechosFim[i], agora);
            if (ate <= de) continue;
            duracaoMs += ate - de;
            metrosJanela += trechosVelocidade[i] * (ate - de) / 1000.0;
        }
        if (duracaoMs < 3000) return; // Aquecimento mínimo; depois suaviza por até 12 s.
        double mediaMps = metrosJanela * 1000 / duracaoMs;
        if (mediaMps >= VELOCIDADE_MIN_MPS) paceAtual = 1000 / mediaMps;
    }

    @Override
    public void onStatusChanged(String provedor, int status, Bundle extras) {
        evento("gps status " + status);
    }

    @Override
    public void onProviderEnabled(String provedor) {
        evento("gps ligado");
    }

    @Override
    public void onProviderDisabled(String provedor) {
        perderReferencia();
        evento("gps desligado");
    }

    private void contarSatelites() {
        if (local == null) return;
        try {
            GpsStatus s = local.getGpsStatus(null);
            if (s == null) return;
            int vistos = 0;
            int usados = 0;
            for (GpsSatellite sat : s.getSatellites()) {
                vistos++;
                if (sat.usedInFix()) usados++;
            }
            satelitesVistos = vistos;
            satelitesUsados = usados;
        } catch (SecurityException e) {
            // Sem permissão: fica zero.
        }
    }

    // MARK: Registro

    private void abrirLog() {
        try {
            File pasta = new File(Environment.getExternalStorageDirectory(), "CRUNNING-sonda");
            if (!pasta.exists() && !pasta.mkdirs()) {
                arquivo = "sem arquivo: pasta indisponivel";
                return;
            }
            String nome = "sonda-" + new SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(new Date()) + ".csv";
            File f = new File(pasta, nome);
            log = new PrintWriter(new FileWriter(f, true));
            arquivo = f.getAbsolutePath();
            log.println("segundos,bpm,gps_fixo,precisao_m,velocidade_mps,satelites_usados,satelites_vistos,bateria,tela_ligada,app_visivel,distancia_m,pace_atual_s_km,pace_medio_s_km");
            log.flush();
        } catch (IOException | SecurityException e) {
            log = null;
            arquivo = "sem arquivo: armazenamento indisponivel";
        }
    }

    private long segundos() {
        return (SystemClock.elapsedRealtime() - inicio) / 1000;
    }

    private void evento(String texto) {
        if (log == null) return;
        log.println("# " + segundos() + " " + texto);
        log.flush();
    }

    private void gravarLinha() {
        long agora = SystemClock.elapsedRealtime();
        Intent bat = registerReceiver(null, filtroBateria);
        if (bat != null) {
            int nivel = bat.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
            int escala = bat.getIntExtra(BatteryManager.EXTRA_SCALE, 100);
            bateria = nivel < 0 || escala <= 0 ? -1
                    : (int) Math.min(100L, (long) nivel * 100 / escala);
        }
        boolean fcRecente = bpmEm > 0 && agora - bpmEm <= 5000;
        boolean fixo = gpsEm > 0 && agora - gpsEm <= 3000;
        boolean telaLigada = energia != null && energia.isInteractive();
        if (log == null) return;
        log.println(segundos() + "," + (fcRecente ? bpm : "") + "," + (fixo ? 1 : 0) + ","
                + (fixo ? Math.round(precisao) : "") + "," + (fixo ? String.format(Locale.US, "%.1f", velocidade) : "") + ","
                + satelitesUsados + "," + satelitesVistos + "," + bateria + ","
                + (telaLigada ? 1 : 0) + "," + (telaVisivel ? 1 : 0) + ","
                + String.format(Locale.US, "%.2f", distanciaM) + ","
                + (paceAtual > 0 ? String.format(Locale.US, "%.1f", paceAtual) : "") + ","
                + (paceMedio > 0 ? String.format(Locale.US, "%.1f", paceMedio) : ""));
        log.flush();
    }
}
