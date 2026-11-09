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
 * sinal, a precisão, a velocidade e os satélites, para medir se o app sobrevive com a tela
 * apagada sem guardar por onde você correu.
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
    static volatile float precisao;
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

    private final Runnable tique = new Runnable() {
        @Override
        public void run() {
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

        Notification aviso = new Notification.Builder(this)
                .setContentTitle("CRUNNING sonda")
                .setContentText("Gravando batimento e GPS")
                .setSmallIcon(android.R.drawable.ic_menu_mylocation)
                .setOngoing(true)
                .build();
        startForeground(1, aviso);

        energia = (PowerManager) getSystemService(POWER_SERVICE);
        trava = energia.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "crunning:sonda");
        trava.acquire();

        abrirLog();
        // Intent nulo = o sistema matou o processo e recriou o serviço (START_STICKY).
        evento(intent == null ? "inicio (recriado pelo sistema)" : "inicio");

        sensores = (SensorManager) getSystemService(SENSOR_SERVICE);
        Sensor fc = sensores.getDefaultSensor(Sensor.TYPE_HEART_RATE);
        if (fc != null) {
            sensores.registerListener(this, fc, SensorManager.SENSOR_DELAY_NORMAL);
            evento("sensor de FC: " + fc.getName() + " / " + fc.getVendor());
        } else {
            evento("sem sensor de FC");
        }

        local = (LocationManager) getSystemService(LOCATION_SERVICE);
        try {
            local.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000, 0, this);
            ouvinteGps = new GpsStatus.Listener() {
                @Override
                public void onGpsStatusChanged(int qual) {
                    if (qual == GpsStatus.GPS_EVENT_SATELLITE_STATUS) contarSatelites();
                }
            };
            local.addGpsStatusListener(ouvinteGps);
        } catch (SecurityException | IllegalArgumentException e) {
            evento("gps indisponivel: " + e);
        }

        handler = new Handler();
        handler.post(tique);
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        evento("fim");
        if (handler != null) handler.removeCallbacks(tique);
        if (sensores != null) sensores.unregisterListener(this);
        if (local != null) {
            local.removeUpdates(this);
            if (ouvinteGps != null) local.removeGpsStatusListener(ouvinteGps);
        }
        if (trava != null && trava.isHeld()) trava.release();
        stopForeground(true);
        rodando = false;
        if (log != null) log.close();
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
        if (e.sensor.getType() != Sensor.TYPE_HEART_RATE || e.values.length == 0) return;
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
        gpsEm = SystemClock.elapsedRealtime();
        precisao = l.hasAccuracy() ? l.getAccuracy() : -1;
        velocidade = l.hasSpeed() ? l.getSpeed() : -1;
        leiturasGPS++;
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
        evento("gps desligado");
    }

    private void contarSatelites() {
        try {
            GpsStatus s = local.getGpsStatus(null);
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
            if (!pasta.exists() && !pasta.mkdirs()) return;
            String nome = "sonda-" + new SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US).format(new Date()) + ".csv";
            File f = new File(pasta, nome);
            log = new PrintWriter(new FileWriter(f, true));
            arquivo = f.getAbsolutePath();
            log.println("segundos,bpm,gps_fixo,precisao_m,velocidade_mps,satelites_usados,satelites_vistos,bateria,tela_ligada,app_visivel");
            log.flush();
        } catch (IOException e) {
            log = null;
            arquivo = "sem arquivo: " + e.getMessage();
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
        Intent bat = registerReceiver(null, new IntentFilter(Intent.ACTION_BATTERY_CHANGED));
        if (bat != null) {
            int nivel = bat.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
            int escala = bat.getIntExtra(BatteryManager.EXTRA_SCALE, 100);
            bateria = nivel < 0 ? -1 : nivel * 100 / Math.max(escala, 1);
        }
        boolean fcRecente = bpmEm > 0 && agora - bpmEm <= 5000;
        boolean fixo = gpsEm > 0 && agora - gpsEm <= 3000;
        boolean telaLigada = energia != null && energia.isInteractive();
        if (log == null) return;
        log.println(segundos() + "," + (fcRecente ? bpm : "") + "," + (fixo ? 1 : 0) + ","
                + (fixo ? Math.round(precisao) : "") + "," + (fixo ? String.format(Locale.US, "%.1f", velocidade) : "") + ","
                + satelitesUsados + "," + satelitesVistos + "," + bateria + ","
                + (telaLigada ? 1 : 0) + "," + (telaVisivel ? 1 : 0));
        log.flush();
    }
}
