package io.github.caiosmiderle.crunning.sonda;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Color;
import android.os.Bundle;
import android.os.Handler;
import android.os.SystemClock;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.util.Locale;

/**
 * Tela da sonda (320x300): batimento grande, estado do GPS, tempo gravado e os botões para
 * começar/parar e para testar a tela sempre acesa. Fundo preto e texto claro, pensando na
 * tela transflexiva do Pace.
 */
public class Principal extends Activity {
    private TextView textoBpm;
    private TextView textoGps;
    private TextView textoTempo;
    private TextView textoContagem;
    private Button botaoGravar;
    private Button botaoTela;
    private boolean telaSempre;
    private final Handler handler = new Handler();

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
        LinearLayout raiz = new LinearLayout(this);
        raiz.setOrientation(LinearLayout.VERTICAL);
        raiz.setGravity(Gravity.CENTER);
        raiz.setBackgroundColor(Color.BLACK);
        raiz.setPadding(dp(12), dp(4), dp(12), dp(4));

        textoBpm = texto(raiz, 40, Color.WHITE);
        textoGps = texto(raiz, 13, Color.LTGRAY);
        textoTempo = texto(raiz, 20, Color.WHITE);
        textoContagem = texto(raiz, 11, Color.GRAY);

        LinearLayout linha = new LinearLayout(this);
        linha.setOrientation(LinearLayout.HORIZONTAL);
        linha.setGravity(Gravity.CENTER);
        botaoGravar = botao(linha);
        botaoTela = botao(linha);
        raiz.addView(linha);

        botaoGravar.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                Intent servico = new Intent(Principal.this, Servico.class);
                if (Servico.rodando) stopService(servico); else startService(servico);
                handler.postDelayed(new Runnable() {
                    @Override
                    public void run() {
                        mostrar();
                    }
                }, 300);
            }
        });
        botaoTela.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                telaSempre = !telaSempre;
                if (telaSempre) {
                    getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                } else {
                    getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
                }
                mostrar();
            }
        });
        setContentView(raiz);
    }

    @Override
    protected void onResume() {
        super.onResume();
        Servico.telaVisivel = true;
        handler.post(atualizar);
    }

    @Override
    protected void onPause() {
        Servico.telaVisivel = false;
        handler.removeCallbacks(atualizar);
        super.onPause();
    }

    private void mostrar() {
        long agora = SystemClock.elapsedRealtime();
        boolean fcRecente = Servico.bpmEm > 0 && agora - Servico.bpmEm <= 5000;
        textoBpm.setText(fcRecente ? "♥ " + Servico.bpm : "♥ --");
        boolean fixo = Servico.gpsEm > 0 && agora - Servico.gpsEm <= 3000;
        textoGps.setText(fixo
                ? String.format(Locale.US, "GPS ok ±%d m · %d sat", Math.round(Servico.precisao), Servico.satelitesUsados)
                : String.format(Locale.US, "GPS procurando · %d sat", Servico.satelitesVistos));
        if (Servico.rodando) {
            long s = (agora - Servico.inicio) / 1000;
            textoTempo.setText(String.format(Locale.US, "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60));
        } else {
            textoTempo.setText("parado");
        }
        textoContagem.setText("FC " + Servico.leiturasFC + " · GPS " + Servico.leiturasGPS
                + " · bat " + (Servico.bateria < 0 ? "?" : Servico.bateria + "%"));
        botaoGravar.setText(Servico.rodando ? "Parar" : "Começar");
        botaoTela.setText(telaSempre ? "Tela: sempre" : "Tela: normal");
    }

    private TextView texto(LinearLayout pai, int tamanhoSp, int cor) {
        TextView t = new TextView(this);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, tamanhoSp);
        t.setTextColor(cor);
        t.setGravity(Gravity.CENTER);
        t.setSingleLine(true);
        pai.addView(t, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));
        return t;
    }

    private Button botao(LinearLayout pai) {
        Button b = new Button(this);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 12);
        b.setAllCaps(false);
        b.setMinHeight(0);
        b.setMinimumHeight(0);
        b.setPadding(dp(8), dp(4), dp(8), dp(4));
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(0, dp(40), 1);
        p.setMargins(dp(2), dp(4), dp(2), 0);
        pai.addView(b, p);
        return b;
    }

    private int dp(int valor) {
        return Math.round(valor * getResources().getDisplayMetrics().density);
    }
}
