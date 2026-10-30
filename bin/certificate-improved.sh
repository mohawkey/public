#!/usr/bin/env bash
# Local development CA and TLS server certificate generator.
# Requires Bash 4+ and OpenSSL 1.1.1+.
set -Eeuo pipefail
umask 077
TMP_DIR=""
trap '[[ -z "$TMP_DIR" ]] || rm -rf -- "$TMP_DIR"' EXIT

BASE_DIR="${CERT_DIR:-.certificate}"
CA_DIR="$BASE_DIR/root-certificate"
CA_KEY="$CA_DIR/rootca.key"
CA_CERT="$CA_DIR/rootca.crt"
CA_SERIAL="$CA_DIR/rootca.srl"
COUNTRY="${CERT_COUNTRY:-BE}"
ORGANIZATION="${CERT_ORGANIZATION:-Local Development}"
CA_NAME="${CERT_CA_NAME:-Local Development Root CA}"

usage() {
  cat <<'USAGE'
Usage:
  certificate-improved.sh init-ca
  certificate-improved.sh issue DOMAIN [--ip IPv4]
  certificate-improved.sh                 # interactive mode

Environment:
  CERT_DIR           Output directory (default: .certificate)
  CERT_COUNTRY       Two-letter country code (default: BE)
  CERT_ORGANIZATION  CA organization (default: Local Development)
  CERT_CA_NAME       CA common name (default: Local Development Root CA)

Examples:
  ./certificate-improved.sh init-ca
  ./certificate-improved.sh issue app.home.test --ip 192.168.1.10
  ./certificate-improved.sh issue '*.home.test'

Keep rootca.key private. Trust rootca.crt only on machines you control.
USAGE
}

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }

validate_domain() {
  local domain="$1" label
  [[ ${#domain} -le 253 && -n "$domain" ]] || die "Invalid domain length"
  if [[ "$domain" == '*.'* ]]; then domain="${domain#*.}"; fi
  [[ "$domain" == *.* ]] || die "Domain must contain at least one dot"
  [[ "$domain" =~ ^[A-Za-z0-9.-]+$ ]] || die "Invalid domain: $1"
  [[ "$domain" != .* && "$domain" != *. && "$domain" != *..* ]] || die "Invalid domain: $1"
  local -a labels
  IFS='.' read -r -a labels <<< "$domain"
  for label in "${labels[@]}"; do
    [[ ${#label} -ge 1 && ${#label} -le 63 && "$label" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]] || die "Invalid DNS label: $label"
  done
}

validate_ipv4() {
  local ip="$1" part
  local -a parts
  [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "Invalid IPv4 address: $ip"
  IFS='.' read -r -a parts <<< "$ip"
  for part in "${parts[@]}"; do
    [[ ${#part} -le 3 && $((10#$part)) -le 255 ]] || die "Invalid IPv4 address: $ip"
  done
}

validate_subject() {
  [[ "$COUNTRY" =~ ^[A-Za-z]{2}$ ]] || die "CERT_COUNTRY must be two letters"
  [[ "$ORGANIZATION" != *'/'* && "$ORGANIZATION" != *$'\n'* && -n "$ORGANIZATION" ]] || die "Invalid CERT_ORGANIZATION"
  [[ "$CA_NAME" != *'/'* && "$CA_NAME" != *$'\n'* && -n "$CA_NAME" ]] || die "Invalid CERT_CA_NAME"
}

check_ca() {
  [[ -f "$CA_KEY" && -f "$CA_CERT" ]] || die "CA missing; run 'init-ca' first"
  local key_hash cert_hash
  key_hash="$(openssl pkey -in "$CA_KEY" -pubout -outform DER | openssl dgst -sha256)"
  cert_hash="$(openssl x509 -in "$CA_CERT" -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256)"
  [[ "$key_hash" == "$cert_hash" ]] || die "CA certificate and key do not match"
  openssl verify -CAfile "$CA_CERT" "$CA_CERT" >/dev/null || die "CA certificate verification failed"
  openssl x509 -in "$CA_CERT" -noout -text | grep -q 'CA:TRUE' || die "Existing CA lacks CA:TRUE"
}

init_ca() {
  validate_subject
  mkdir -p -- "$CA_DIR"
  if [[ -e "$CA_KEY" || -e "$CA_CERT" ]]; then
    [[ -f "$CA_KEY" && -f "$CA_CERT" ]] || die "Incomplete CA exists; inspect $CA_DIR (nothing overwritten)"
    check_ca
    printf 'CA already exists: %s\n' "$CA_CERT"
    return
  fi

  local tmp
  tmp="$(mktemp -d "$CA_DIR/.tmp.XXXXXXXX")"
  TMP_DIR="$tmp"
  cat > "$tmp/ca.cnf" <<'CONFIG'
[ req ]
distinguished_name = dn
x509_extensions = v3_ca
prompt = no
[ dn ]
CN = placeholder
[ v3_ca ]
basicConstraints = critical, CA:TRUE, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
CONFIG

  printf 'Generating 4096-bit RSA CA key...\n'
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:4096 -out "$tmp/rootca.key" 2> /dev/null
  openssl req -new -x509 -sha256 -days 3650 \
    -key "$tmp/rootca.key" -out "$tmp/rootca.crt" \
    -subj "/C=$COUNTRY/O=$ORGANIZATION/CN=$CA_NAME" \
    -config "$tmp/ca.cnf" -extensions v3_ca
  chmod 600 "$tmp/rootca.key"
  chmod 644 "$tmp/rootca.crt"
  mv -- "$tmp/rootca.key" "$CA_KEY"
  mv -- "$tmp/rootca.crt" "$CA_CERT"
  rm -rf -- "$tmp"
  TMP_DIR=""
  printf 'Created CA certificate: %s\n' "$CA_CERT"
  printf 'CA private key (keep secret): %s\n' "$CA_KEY"
}

issue_cert() {
  local domain="$1" ip="${2:-}" safe_name outdir tmp
  validate_domain "$domain"
  [[ -z "$ip" ]] || validate_ipv4 "$ip"
  check_ca

  safe_name="${domain//\*/_wildcard}"
  outdir="$BASE_DIR/$safe_name"
  mkdir -p -- "$outdir"
  if [[ -e "$outdir/server.key" || -e "$outdir/server.crt" ]]; then
    die "Certificate or key already exists in $outdir; refusing to overwrite"
  fi

  tmp="$(mktemp -d "$outdir/.tmp.XXXXXXXX")"
  TMP_DIR="$tmp"
  {
    printf '[ v3_server ]\n'
    printf 'basicConstraints = critical, CA:FALSE\n'
    printf 'keyUsage = critical, digitalSignature, keyEncipherment\n'
    printf 'extendedKeyUsage = serverAuth\n'
    printf 'subjectKeyIdentifier = hash\n'
    printf 'authorityKeyIdentifier = keyid,issuer\n'
    printf 'subjectAltName = @alt_names\n'
    printf '[ alt_names ]\nDNS.1 = %s\n' "$domain"
    [[ -z "$ip" ]] || printf 'IP.1 = %s\n' "$ip"
  } > "$tmp/server.ext"

  printf 'Generating server key and certificate for %s...\n' "$domain"
  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "$tmp/server.key" 2>/dev/null
  openssl req -new -sha256 -key "$tmp/server.key" -subj "/CN=$domain" -out "$tmp/server.csr"
  openssl x509 -req -sha256 -days 365 \
    -in "$tmp/server.csr" -CA "$CA_CERT" -CAkey "$CA_KEY" \
    -CAserial "$CA_SERIAL" -CAcreateserial \
    -out "$tmp/server.crt" -extfile "$tmp/server.ext" -extensions v3_server
  openssl verify -CAfile "$CA_CERT" -purpose sslserver "$tmp/server.crt" >/dev/null
  chmod 600 "$tmp/server.key"
  chmod 644 "$tmp/server.crt"
  mv -- "$tmp/server.key" "$outdir/server.key"
  mv -- "$tmp/server.crt" "$outdir/server.crt"
  rm -rf -- "$tmp"
  TMP_DIR=""
  printf 'Certificate: %s\nPrivate key: %s\nCA cert: %s\n' "$outdir/server.crt" "$outdir/server.key" "$CA_CERT"
}

main() {
  command -v openssl >/dev/null || die "OpenSSL is required"
  local action="${1:-}" domain ip="" answer
  if [[ $# -eq 0 ]]; then
    read -r -p 'Create/check local CA? [Y/n] ' answer
    [[ "${answer,,}" != n ]] || return 0
    init_ca
    read -r -p 'Domain to issue (leave blank to stop): ' domain
    [[ -n "$domain" ]] || return 0
    read -r -p 'Optional IPv4 SAN (blank for none): ' ip
    issue_cert "$domain" "$ip"
    return
  fi
  case "$action" in
    init-ca) [[ $# -eq 1 ]] || die "Unexpected arguments"; init_ca ;;
    issue)
      [[ $# -ge 2 ]] || die "Specify a domain"
      domain="$2"
      shift 2
      if [[ $# -gt 0 ]]; then
        [[ $# -eq 2 && "$1" == '--ip' ]] || die "Expected --ip IPv4"
        ip="$2"
      fi
      issue_cert "$domain" "$ip"
      ;;
    -h|--help|help) usage ;;
    *) usage >&2; exit 2 ;;
  esac
}
main "$@"
