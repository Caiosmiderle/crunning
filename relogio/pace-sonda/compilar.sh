#!/usr/bin/env bash
# Compila a sonda do Amazfit Pace sem Gradle, só com as ferramentas oficiais do Android:
# aapt2 (manifesto), javac (Java 8), d8 (dex), zipalign e apksigner. Roda no GitHub Actions
# (ubuntu, que já traz o SDK e o JDK). Uso: bash compilar.sh <número da versão>
set -euo pipefail

VERSAO="${1:-1}"
AQUI="$(cd "$(dirname "$0")" && pwd)"
SDK="${ANDROID_HOME:-${ANDROID_SDK_ROOT:?defina ANDROID_HOME}}"

# Compila contra o Android 5.1 (API 22), o sistema do Pace: assim nenhuma API mais nova entra.
# (yes || true): o yes termina com "broken pipe" quando o sdkmanager para de ler, e o pipefail
# acusaria erro.
(yes || true) | "$SDK/cmdline-tools/latest/bin/sdkmanager" "platforms;android-22" > /dev/null
JAR="$SDK/platforms/android-22/android.jar"
test -f "$JAR" || { echo "android-22 não instalou"; exit 1; }
BT="$SDK/build-tools/$(ls "$SDK/build-tools" | sort -V | tail -1)"
echo "build-tools: $BT"

SAIDA="$AQUI/saida"
rm -rf "$SAIDA"
mkdir -p "$SAIDA/classes" "$SAIDA/dex"

"$BT/aapt2" link -I "$JAR" --manifest "$AQUI/AndroidManifest.xml" \
  --min-sdk-version 22 --target-sdk-version 22 \
  --version-code "$VERSAO" --version-name "0.1.$VERSAO" \
  -o "$SAIDA/base.apk"

javac -source 8 -target 8 -encoding UTF-8 -Xlint:-options \
  -bootclasspath "$JAR" -classpath "$JAR" \
  -d "$SAIDA/classes" $(find "$AQUI/src" -name '*.java')

"$BT/d8" --min-api 22 --lib "$JAR" --output "$SAIDA/dex" $(find "$SAIDA/classes" -name '*.class')
(cd "$SAIDA/dex" && zip -q "$SAIDA/base.apk" classes.dex)

"$BT/zipalign" -f -p 4 "$SAIDA/base.apk" "$SAIDA/alinhado.apk"

# Chave descartável, criada a cada compilação (app de teste; reinstalar pede desinstalar antes).
keytool -genkeypair -keystore "$SAIDA/sonda.keystore" -storepass android -keypass android \
  -alias sonda -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=CRUNNING sonda" > /dev/null 2>&1
"$BT/apksigner" sign --ks "$SAIDA/sonda.keystore" --ks-pass pass:android --key-pass pass:android \
  --out "$SAIDA/crunning-sonda.apk" "$SAIDA/alinhado.apk"
"$BT/apksigner" verify --min-sdk-version 22 --verbose "$SAIDA/crunning-sonda.apk" | head -5
sha256sum "$SAIDA/crunning-sonda.apk" | tee "$SAIDA/crunning-sonda.apk.sha256"
