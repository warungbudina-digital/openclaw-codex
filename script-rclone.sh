sudo apt update
sudo apt install -y jq

echo "⬇️ Install rclone..."
curl https://rclone.org/install.sh | sudo bash

# ========================
# Bagian: RCLONE CONF
# ========================
REMOTE_NAME="gdrive"
TOKEN_FILE="./token.json"
RCLONE_CONF_PATH="$HOME/.config/rclone/rclone.conf"
DEST_FOLDER="$(pwd)"
GDRIVE_FOLDER="Project-Tutorial/layer-miner/layer-bot"

if [ ! -f "$TOKEN_FILE" ]; then
  echo "❌ File token.json tidak ditemukan di path: $TOKEN_FILE"
  exit 1
fi

echo "⚙️ Menyiapkan rclone.conf..."
mkdir -p "$(dirname "$RCLONE_CONF_PATH")"
TOKEN=$(jq -c . "$TOKEN_FILE")

cat > "$RCLONE_CONF_PATH" <<EOF
[$REMOTE_NAME]
type = drive
scope = drive
token = $TOKEN
EOF

echo "✅ rclone.conf berhasil dibuat."

echo "📁 Menyalin file layer-miner dari Drive ke $DEST_FOLDER ..."
rclone copy --config="$RCLONE_CONF_PATH" "$REMOTE_NAME:$GDRIVE_FOLDER" "$DEST_FOLDER" --progress

sudo docker load -i chromium-stable.tar
sudo rm -f chromium-stable.tar
sudo rm -f chromium-data.tar.gz
