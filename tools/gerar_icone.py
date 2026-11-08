"""Gera o ícone e as imagens da marca do CRUNNING a partir do logo original.

Uso (na raiz do repositório):
    python -I tools/gerar_icone.py design/logo-crunning.png

Não depende de bibliotecas externas: lê e escreve PNG só com zlib e struct.
Entrada: o logo horizontal (símbolo "C" verde + palavra "CRUNNING" preta, fundo branco).
Saídas em App/Recursos/Assets.xcassets:
  AppIcon.appiconset/AppIcon-1024.png  ícone 1024x1024 (símbolo verde sobre fundo escuro)
  Simbolo.imageset/Simbolo.png         só o "C", verde, fundo transparente
  Marca.imageset/Marca.png             só a palavra, como máscara (usada como template)
e imprime a cor verde medida, que vira a cor de destaque do app.
"""

import math
import os
import struct
import sys
import zlib

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(RAIZ, "App", "Recursos", "Assets.xcassets")


# ---------------------------------------------------------------- PNG

def ler_png(caminho):
    dados = open(caminho, "rb").read()
    if dados[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit("o arquivo não é PNG")
    pos, idat = 8, []
    largura = altura = profundidade = tipo_cor = entrelacado = None
    while pos < len(dados):
        (n,) = struct.unpack(">I", dados[pos:pos + 4])
        tipo = dados[pos + 4:pos + 8]
        corpo = dados[pos + 8:pos + 8 + n]
        pos += 12 + n
        if tipo == b"IHDR":
            largura, altura, profundidade, tipo_cor, _, _, entrelacado = struct.unpack(">IIBBBBB", corpo)
        elif tipo == b"IDAT":
            idat.append(corpo)
        elif tipo == b"IEND":
            break
    if profundidade != 8 or tipo_cor not in (2, 6) or entrelacado != 0:
        raise SystemExit("PNG não suportado (precisa ser RGB/RGBA 8 bits, sem entrelaçamento)")
    bpp = 4 if tipo_cor == 6 else 3
    bruto = zlib.decompress(b"".join(idat))
    passo = largura * bpp
    linhas, anterior, i = [], bytearray(passo), 0
    for _ in range(altura):
        filtro = bruto[i]
        i += 1
        linha = bytearray(bruto[i:i + passo])
        i += passo
        if filtro == 1:
            for x in range(bpp, passo):
                linha[x] = (linha[x] + linha[x - bpp]) & 255
        elif filtro == 2:
            for x in range(passo):
                linha[x] = (linha[x] + anterior[x]) & 255
        elif filtro == 3:
            for x in range(passo):
                esq = linha[x - bpp] if x >= bpp else 0
                linha[x] = (linha[x] + ((esq + anterior[x]) >> 1)) & 255
        elif filtro == 4:
            for x in range(passo):
                a = linha[x - bpp] if x >= bpp else 0
                b = anterior[x]
                c = anterior[x - bpp] if x >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                linha[x] = (linha[x] + pred) & 255
        linhas.append(linha)
        anterior = linha
    return largura, altura, bpp, linhas


def escrever_png(caminho, largura, altura, linhas, com_alfa):
    tipo_cor = 6 if com_alfa else 2
    bruto = b"".join(b"\x00" + bytes(l) for l in linhas)

    def bloco(tipo, corpo):
        return struct.pack(">I", len(corpo)) + tipo + corpo + struct.pack(">I", zlib.crc32(tipo + corpo) & 0xFFFFFFFF)

    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with open(caminho, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(bloco(b"IHDR", struct.pack(">IIBBBBB", largura, altura, 8, tipo_cor, 0, 0, 0)))
        f.write(bloco(b"IDAT", zlib.compress(bruto, 9)))
        f.write(bloco(b"IEND", b""))


# ---------------------------------------------------------------- análise do logo

def pixel_sobre_branco(linhas, bpp, x, y):
    """Cor do pixel composta sobre branco (o logo pode ter fundo transparente)."""
    l = linhas[y]
    r, g, b = l[x * bpp], l[x * bpp + 1], l[x * bpp + 2]
    if bpp == 4:
        a = l[x * bpp + 3] / 255
        r, g, b = r * a + 255 * (1 - a), g * a + 255 * (1 - a), b * a + 255 * (1 - a)
    return r, g, b


def eh_verde(r, g, b):
    return g > 150 and g - r > 40 and b < 140


def eh_escuro(r, g, b):
    return r < 110 and g < 110 and b < 110


def caixa(largura, altura, linhas, bpp, teste, x_max=None):
    x0, y0, x1, y1 = largura, altura, -1, -1
    for y in range(altura):
        for x in range(0, x_max or largura):
            if teste(*pixel_sobre_branco(linhas, bpp, x, y)):
                x0, y0, x1, y1 = min(x0, x), min(y0, y), max(x1, x), max(y1, y)
    return x0, y0, x1, y1


def main():
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    largura, altura, bpp, linhas = ler_png(sys.argv[1])

    # Símbolo: pixels verdes. Palavra: pixels escuros à direita do símbolo.
    sx0, sy0, sx1, sy1 = caixa(largura, altura, linhas, bpp, eh_verde)
    mx0, my0, mx1, my1 = caixa(largura, altura, linhas, bpp,
                               lambda r, g, b: eh_escuro(r, g, b))
    mx0 = max(mx0, sx1 + 1)

    # Cor do verde: média dos pixels bem saturados (azul quase zero).
    soma, n = [0, 0, 0], 0
    for y in range(sy0, sy1 + 1, 2):
        for x in range(sx0, sx1 + 1, 2):
            r, g, b = pixel_sobre_branco(linhas, bpp, x, y)
            if eh_verde(r, g, b) and b < 25:
                soma[0] += r; soma[1] += g; soma[2] += b; n += 1
    verde = tuple(round(c / n) for c in soma)
    print("símbolo:", (sx0, sy0, sx1, sy1), "palavra:", (mx0, my0, mx1, my1))
    print("verde do logo: #%02X%02X%02X" % verde)

    # Opacidade do símbolo pelo "quanto é verde": num pixel verde misturado com
    # branco, G - B = a * (G_verde - B_verde). Cinza e preto (a palavra, que encosta
    # na caixa do símbolo) têm G - B ~ 0 e somem.
    def alfa_simbolo(x, y):
        if x < sx0 or x > sx1 or y < sy0 or y > sy1:
            return 0.0
        r, g, b = pixel_sobre_branco(linhas, bpp, x, y)
        return max(0.0, min(1.0, (g - b) / (verde[1] - verde[2])))

    # Palavra: preto sobre branco -> a = 1 - luminância.
    def alfa_marca(x, y):
        r, g, b = pixel_sobre_branco(linhas, bpp, x, y)
        lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return max(0.0, min(1.0, 1 - lum / 255))

    # ---- Simbolo.png (resolução original, margem de 8 px)
    m = 8
    w, h = sx1 - sx0 + 1 + 2 * m, sy1 - sy0 + 1 + 2 * m
    saida = []
    for y in range(h):
        linha = bytearray()
        for x in range(w):
            a = alfa_simbolo(sx0 - m + x, sy0 - m + y)
            linha += bytes((verde[0], verde[1], verde[2], round(a * 255)))
        saida.append(linha)
    escrever_png(os.path.join(ASSETS, "Simbolo.imageset", "Simbolo.png"), w, h, saida, True)

    # ---- Marca.png (máscara preta, resolução original)
    w, h = mx1 - mx0 + 1 + 2 * m, my1 - my0 + 1 + 2 * m
    saida = []
    for y in range(h):
        linha = bytearray()
        for x in range(w):
            xx, yy = mx0 - m + x, my0 - m + y
            a = alfa_marca(xx, yy) if 0 <= xx < largura and 0 <= yy < altura else 0.0
            linha += bytes((0, 0, 0, round(a * 255)))
        saida.append(linha)
    escrever_png(os.path.join(ASSETS, "Marca.imageset", "Marca.png"), w, h, saida, True)

    # ---- AppIcon-1024.png: fundo escuro com brilho verde suave + símbolo centralizado
    T = 1024
    sw, sh = sx1 - sx0 + 1, sy1 - sy0 + 1
    escala = (T * 0.60) / max(sw, sh)
    ox = (T - sw * escala) / 2 + T * 0.01   # leve ajuste óptico: o C é inclinado
    oy = (T - sh * escala) / 2
    topo, base = (28, 33, 44), (8, 10, 14)

    def amostra(fx, fy):
        """Bilinear da opacidade do símbolo em coordenadas do logo."""
        x0, y0 = math.floor(fx), math.floor(fy)
        tx, ty = fx - x0, fy - y0
        a00 = alfa_simbolo(x0, y0); a10 = alfa_simbolo(x0 + 1, y0)
        a01 = alfa_simbolo(x0, y0 + 1); a11 = alfa_simbolo(x0 + 1, y0 + 1)
        return (a00 * (1 - tx) + a10 * tx) * (1 - ty) + (a01 * (1 - tx) + a11 * tx) * ty

    saida = []
    for y in range(T):
        t = y / (T - 1)
        fundo_linha = [topo[i] * (1 - t) + base[i] * t for i in range(3)]
        linha = bytearray()
        for x in range(T):
            d = math.hypot(x - T * 0.5, y - T * 0.5) / (T * 0.42)
            brilho = 0.16 * math.exp(-d * d)
            cor = [fundo_linha[i] * (1 - brilho) + verde[i] * brilho for i in range(3)]
            fx = sx0 + (x + 0.5 - ox) / escala - 0.5
            fy = sy0 + (y + 0.5 - oy) / escala - 0.5
            a = amostra(fx, fy) if (sx0 - 1 <= fx <= sx1 + 1 and sy0 - 1 <= fy <= sy1 + 1) else 0.0
            linha += bytes(round(cor[i] * (1 - a) + verde[i] * a) for i in range(3))
        saida.append(linha)
    escrever_png(os.path.join(ASSETS, "AppIcon.appiconset", "AppIcon-1024.png"), T, T, saida, False)
    print("ok: ícone, símbolo e marca gerados em", ASSETS)


if __name__ == "__main__":
    main()
