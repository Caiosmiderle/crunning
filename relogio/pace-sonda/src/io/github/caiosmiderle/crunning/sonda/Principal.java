package io.github.caiosmiderle.crunning.sonda;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.location.LocationManager;
import android.os.Bundle;
import android.os.Handler;
import android.os.SystemClock;
import android.util.Log;
import android.util.TypedValue;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.Button;

import java.util.Locale;

/** Painel desenhado para os 320 x 300 pixels físicos do Pace, sem forçar orientação. */
public class Principal extends Activity {
    private Painel painel;
    private boolean telaSempre;
    private boolean acaoPendente;
    private long confirmarAte;
    private boolean confirmacaoVisivel;
    private long confirmarAgpsAte;
    private boolean confirmacaoAgpsVisivel;
    private long resultadoAgpsAte;
    private String resultadoAgps = "";
    private final Handler handler = new Handler();

    // Um único pulso visual; toques alteram o estado, mostrado no próximo pulso (até 1 s).
    private final Runnable atualizar = new Runnable() {
        @Override
        public void run() {
            mostrar();
            handler.postDelayed(this, 1000);
        }
    };

    @Override
    protected void onCreate(Bundle estado) {
        super.onCreate(estado);
        telaSempre = estado != null && estado.getBoolean("telaSempre", false);
        aplicarTela();
        painel = new Painel();
        painel.gravar.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                if (acaoPendente) return;
                confirmarAgpsAte = 0;
                confirmacaoAgpsVisivel = false;
                long agora = SystemClock.elapsedRealtime();
                Intent servico = new Intent(Principal.this, Servico.class);
                if (!Servico.rodando) {
                    confirmarAte = 0;
                    startService(servico);
                    acaoPendente = true;
                } else if (confirmacaoVisivel && confirmarAte > 0 && agora <= confirmarAte) {
                    confirmarAte = 0;
                    stopService(servico);
                    acaoPendente = true;
                } else if (confirmarAte == 0 || agora > confirmarAte) {
                    confirmarAte = agora + 3000;
                    confirmacaoVisivel = false;
                }
            }
        });
        painel.tela.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                telaSempre = !telaSempre;
                confirmarAte = 0;
                confirmacaoVisivel = false;
                confirmarAgpsAte = 0;
                confirmacaoAgpsVisivel = false;
                aplicarTela();
            }
        });
        painel.alvoGps.setOnLongClickListener(new View.OnLongClickListener() {
            @Override
            public boolean onLongClick(View v) {
                long agora = SystemClock.elapsedRealtime();
                confirmarAte = 0;
                confirmacaoVisivel = false;
                if (confirmacaoAgpsVisivel && confirmarAgpsAte > 0 && agora <= confirmarAgpsAte) {
                    apagarAgps();
                } else if (confirmarAgpsAte == 0 || agora > confirmarAgpsAte) {
                    confirmarAgpsAte = agora + 3000;
                    confirmacaoAgpsVisivel = false;
                    resultadoAgpsAte = 0;
                }
                return true;
            }
        });
        setContentView(painel);
        tratarAcao(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        tratarAcao(intent);
    }

    private void tratarAcao(Intent intent) {
        if (intent == null) return;
        String acao;
        try {
            acao = intent.getStringExtra("acao");
            intent.removeExtra("acao"); // Não repete o comando ao recriar a Activity.
        } catch (RuntimeException e) {
            Log.i("CRUNNING", "acao recebida: extra invalido");
            return;
        }
        if (acao == null) return;
        boolean conhecida = "comecar".equals(acao) || "parar".equals(acao)
                || "apagar_agps".equals(acao) || "tela_sempre".equals(acao)
                || "tela_normal".equals(acao);
        // Nunca imprime Intent/extras arbitrários, que poderiam conter dados pessoais.
        Log.i("CRUNNING", "acao recebida: " + (conhecida ? acao : "desconhecida"));
        if (!conhecida) return;
        confirmarAte = 0;
        confirmacaoVisivel = false;
        confirmarAgpsAte = 0;
        confirmacaoAgpsVisivel = false;
        if ("comecar".equals(acao)) {
            startService(new Intent(this, Servico.class));
            acaoPendente = true;
        } else if ("parar".equals(acao)) {
            stopService(new Intent(this, Servico.class));
            acaoPendente = true;
        } else if ("apagar_agps".equals(acao)) {
            apagarAgps();
        } else {
            telaSempre = "tela_sempre".equals(acao);
            aplicarTela();
        }
    }

    private void apagarAgps() {
        confirmarAgpsAte = 0;
        confirmacaoAgpsVisivel = false;
        boolean aceito = false;
        try {
            LocationManager local = (LocationManager) getSystemService(LOCATION_SERVICE);
            if (local == null) {
                resultadoAgps = "AGPS indisponível";
            } else {
                aceito = local.sendExtraCommand(LocationManager.GPS_PROVIDER, "delete_aiding_data", null);
                resultadoAgps = aceito ? "AGPS: pedido aceito" : "AGPS: recusado";
            }
        } catch (SecurityException e) {
            resultadoAgps = "AGPS: sem permissão";
        } catch (RuntimeException e) {
            // Falha do provedor/firmware: não registra exceções ou objetos do GPS.
            resultadoAgps = "AGPS: falhou";
        }
        resultadoAgpsAte = SystemClock.elapsedRealtime() + 5000;
        Servico.registrarApagarAgps(resultadoAgps, aceito);
    }

    private void aplicarTela() {
        if (telaSempre) {
            getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        } else {
            getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle estado) {
        estado.putBoolean("telaSempre", telaSempre);
        super.onSaveInstanceState(estado);
    }

    @Override
    protected void onResume() {
        super.onResume();
        Servico.telaVisivel = true;
        handler.removeCallbacks(atualizar);
        handler.post(atualizar);
    }

    @Override
    protected void onPause() {
        Servico.telaVisivel = false;
        confirmarAte = 0;
        confirmacaoVisivel = false;
        confirmarAgpsAte = 0;
        confirmacaoAgpsVisivel = false;
        handler.removeCallbacks(atualizar);
        super.onPause();
    }

    private void mostrar() {
        long agora = SystemClock.elapsedRealtime();
        boolean gravando = Servico.rodando;
        boolean fcRecente = gravando && Servico.bpmEm > 0 && agora - Servico.bpmEm <= 5000;
        boolean gpsBom = gravando && Servico.gpsBomEm > 0 && agora - Servico.gpsBomEm <= 3000;
        boolean gpsRecente = gravando && Servico.gpsEm > 0 && agora - Servico.gpsEm <= 3000;
        boolean confirmandoAgps = confirmarAgpsAte > 0 && agora <= confirmarAgpsAte;
        if (!confirmandoAgps) confirmarAgpsAte = 0;
        confirmacaoAgpsVisivel = confirmandoAgps;
        boolean confirmando = gravando && confirmarAte > 0 && agora <= confirmarAte;
        if (!confirmando) confirmarAte = 0;
        confirmacaoVisivel = confirmando;
        acaoPendente = false;

        painel.atual = ritmo(gpsBom ? Servico.paceAtual : -1);
        painel.medio = ritmo(Servico.paceMedio);
        long s = Math.max(0, gravando ? agora - Servico.inicio : Servico.tempoGravadoMs) / 1000;
        painel.tempo = s < 3600
                ? String.format(Locale.US, "%02d:%02d", s / 60, s % 60)
                : String.format(Locale.US, "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60);
        painel.fc = fcRecente ? "♥ " + Servico.bpm : "♥ --";
        painel.corFc = fcRecente ? Cores.VERDE_LOGO : Cores.SEM_LEITURA;
        painel.distancia = String.format(Locale.US, "%.2f km", Servico.distanciaM / 1000).replace('.', ',');
        boolean precisaoValida = Servico.temPrecisao && !Float.isNaN(Servico.precisao)
                && !Float.isInfinite(Servico.precisao) && Servico.precisao >= 0;
        painel.gps = gpsRecente ? "GPS ok" : "GPS procurando";
        painel.gps += gpsRecente && precisaoValida ? " ±" + Math.round(Servico.precisao) + " m"
                : " · " + Servico.satelitesVistos + " sat";
        painel.corGps = gpsRecente ? Cores.VERDE_LOGO : Cores.AMARELO;
        if (agora < resultadoAgpsAte) {
            painel.gps = resultadoAgps;
            painel.corGps = Cores.AMARELO;
        }
        painel.alvoGps.setContentDescription(confirmandoAgps
                ? "Segure GPS de novo em até 3 segundos para apagar os dados de apoio"
                : "GPS: segure para pedir limpeza dos dados de apoio");
        painel.bateria = "Bat " + (Servico.bateria < 0 ? "--" : Servico.bateria + "%");
        painel.diagnostico = confirmandoAgps ? "Apagar AGPS? Segure GPS (3 s)"
                : confirmando ? "Toque de novo para parar"
                : "FC " + Servico.leiturasFC + " · GPS " + Servico.leiturasGPS;
        painel.corDiagnostico = confirmando || confirmandoAgps ? Cores.AMARELO : Cores.BRANCO;
        painel.gravar.setText(confirmando ? "Confirmar" : gravando ? "Parar" : "Começar");
        painel.gravar.setBackgroundColor(gravando ? Cores.ALERTA : Cores.VERDE_LOGO);
        painel.gravar.setContentDescription(confirmando ? "Toque de novo para parar em até 3 segundos"
                : gravando ? "Parar gravação, pede confirmação" : "Começar gravação");
        painel.tela.setText(telaSempre ? "Tela:\nsempre" : "Tela:\nnormal");
        painel.tela.setContentDescription(telaSempre ? "Tela: sempre acesa" : "Tela: normal");
        painel.tela.setTextColor(telaSempre ? Cores.PRETO : Cores.VERDE_LOGO);
        painel.tela.setBackgroundColor(telaSempre ? Cores.VERDE_LOGO : Cores.PRETO);
        painel.invalidate();
    }

    private static String ritmo(double segundosKm) {
        // Limite explícito evita minutos enormes, NaN e overflow no arredondamento.
        if (Double.isNaN(segundosKm) || segundosKm <= 0 || segundosKm > 5999) return "--:--";
        long s = Math.round(segundosKm);
        return String.format(Locale.US, "%d:%02d", s / 60, s % 60);
    }

    private final class Painel extends ViewGroup {
        private final Paint tinta = new Paint(Paint.ANTI_ALIAS_FLAG);
        private final Typeface fonte = Typeface.create("sans-serif-condensed", Typeface.BOLD);
        final Button gravar = botao();
        final Button tela = botao();
        final View alvoGps = new View(Principal.this);
        private float escala = 1;
        private float esquerda;
        private float topo;
        String atual = "--:--";
        String medio = "--:--";
        String tempo = "00:00";
        String fc = "♥ --";
        String distancia = "0,00 km";
        String gps = "GPS procurando";
        String bateria = "Bat --";
        String diagnostico = "FC 0 · GPS 0";
        int corFc = Cores.SEM_LEITURA;
        int corGps = Cores.AMARELO;
        int corDiagnostico = Cores.BRANCO;

        Painel() {
            super(Principal.this);
            setWillNotDraw(false);
            setBackgroundColor(Cores.PRETO);
            tinta.setTypeface(fonte);
            tinta.setTextAlign(Paint.Align.CENTER);
            addView(gravar);
            addView(tela);
            addView(alvoGps);
        }

        private Button botao() {
            Button b = new Button(Principal.this);
            b.setTypeface(fonte);
            b.setAllCaps(false);
            b.setTextColor(Cores.PRETO);
            b.setPadding(0, 0, 0, 0);
            b.setMinWidth(0);
            b.setMinimumWidth(0);
            b.setMinHeight(0);
            b.setMinimumHeight(0);
            b.setIncludeFontPadding(false);
            b.setMaxLines(2);
            // API 21: remove a animação de elevação do tema; fundo sólido, sem ripple.
            b.setStateListAnimator(null);
            b.setElevation(0);
            b.setBackgroundColor(Cores.PRETO);
            return b;
        }

        @Override
        protected void onMeasure(int largura, int altura) {
            int w = View.MeasureSpec.getSize(largura);
            int h = View.MeasureSpec.getSize(altura);
            setMeasuredDimension(w, h);
            escala = Math.min(w / 320f, h / 300f);
            esquerda = (w - 320 * escala) / 2;
            topo = (h - 300 * escala) / 2;
            // No Pace: 76 x 66 px = 50,7 x 44 dp. Ambos longe dos cantos.
            int bw = Math.round(76 * escala);
            int bh = Math.round(66 * escala);
            gravar.setTextSize(TypedValue.COMPLEX_UNIT_PX, 16 * escala);
            tela.setTextSize(TypedValue.COMPLEX_UNIT_PX, 16 * escala);
            gravar.measure(View.MeasureSpec.makeMeasureSpec(bw, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(bh, View.MeasureSpec.EXACTLY));
            tela.measure(View.MeasureSpec.makeMeasureSpec(bw, View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(bh, View.MeasureSpec.EXACTLY));
            alvoGps.measure(View.MeasureSpec.makeMeasureSpec(Math.round(160 * escala), View.MeasureSpec.EXACTLY),
                    View.MeasureSpec.makeMeasureSpec(Math.round(24 * escala), View.MeasureSpec.EXACTLY));
        }

        @Override
        protected void onLayout(boolean mudou, int l, int t, int r, int b) {
            posicionar(gravar, 80);
            posicionar(tela, 164);
            int gx = Math.round(esquerda + 42 * escala);
            int gy = Math.round(topo + 176 * escala);
            alvoGps.layout(gx, gy, gx + alvoGps.getMeasuredWidth(), gy + alvoGps.getMeasuredHeight());
        }

        private void posicionar(Button botao, int x) {
            int l = Math.round(esquerda + x * escala);
            int t = Math.round(topo + 208 * escala);
            botao.layout(l, t, l + botao.getMeasuredWidth(), t + botao.getMeasuredHeight());
        }

        @Override
        protected void onDraw(Canvas canvas) {
            super.onDraw(canvas);
            canvas.save();
            canvas.translate(esquerda, topo);
            canvas.scale(escala, escala);
            // Todas as medidas abaixo são pixels de referência, não sp/dp.
            texto(canvas, "RITMO ATUAL · min/km", 160, 32, 16, 156, Cores.VERDE_LOGO);
            texto(canvas, atual, 160, 94, 76, 220, Cores.BRANCO);
            texto(canvas, "MÉDIO · min/km", 94, 113, 13, 116, Cores.BRANCO);
            texto(canvas, "TEMPO", 226, 113, 13, 116, Cores.BRANCO);
            texto(canvas, medio, 94, 143, 32, 116, Cores.BRANCO);
            texto(canvas, tempo, 226, 143, 32, 116, Cores.BRANCO);
            texto(canvas, fc, 94, 174, 28, 116, corFc);
            texto(canvas, distancia, 226, 174, 26, 116, Cores.BRANCO);
            texto(canvas, gps, 121, 190, 14, 150, corGps);
            texto(canvas, bateria, 237, 190, 14, 68, Cores.BRANCO);
            texto(canvas, diagnostico, 160, 203, 13, 232, corDiagnostico);
            // Contorno do alternador continua visível no preto, sem transparência.
            tinta.setColor(Cores.VERDE_LOGO);
            tinta.setStyle(Paint.Style.STROKE);
            tinta.setStrokeWidth(2);
            canvas.drawRect(163, 207, 241, 275, tinta);
            tinta.setStyle(Paint.Style.FILL);
            canvas.restore();
        }

        private void texto(Canvas canvas, String valor, float x, float base,
                           float tamanho, float largura, int cor) {
            tinta.setTextSize(tamanho);
            float medida = tinta.measureText(valor);
            if (medida > largura) tinta.setTextSize(tamanho * largura / medida);
            tinta.setColor(cor);
            canvas.drawText(valor, x, base, tinta);
        }
    }
}
