"""Reduz o ícone do iPhone para o launcher do Pace, preservando a margem circular.

Na raiz do repositório, com Python e Pillow instalados:
    python -I relogio/pace-sonda/ferramentas/gerar_icone.py

Lê somente o AppIcon original; escreve somente em pace-sonda/res/mipmap-*.
O símbolo já ocupa os 60% centrais do original, seguro no recorte em círculo.
"""

from pathlib import Path

try:
    from PIL import Image
except ImportError:
    raise SystemExit("Pillow indisponível. Instale com: python -m pip install Pillow")


SONDA = Path(__file__).resolve().parents[1]
FONTE = (SONDA.parents[1] / "App" / "Recursos" / "Assets.xcassets"
         / "AppIcon.appiconset" / "AppIcon-1024.png")
TAMANHOS = (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144))


def main():
    with Image.open(FONTE) as original:
        if original.width != original.height:
            raise SystemExit("O AppIcon de origem precisa ser quadrado.")
        imagem = original.convert("RGB")
    # Compatível também com Pillow anterior ao enum Resampling.
    lanczos = getattr(Image, "Resampling", Image).LANCZOS
    for densidade, tamanho in TAMANHOS:
        destino = SONDA / "res" / ("mipmap-" + densidade) / "ic_launcher.png"
        destino.parent.mkdir(parents=True, exist_ok=True)
        imagem.resize((tamanho, tamanho), lanczos).save(destino, format="PNG", optimize=True)
        print("Gerado:", destino.relative_to(SONDA), str(tamanho) + "x" + str(tamanho))


if __name__ == "__main__":
    main()
