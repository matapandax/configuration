#!/usr/bin/env bash
#
# Read a list of Ansible variables that should have generated values, and make
# a new file just like it, with the generated values.

REPO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
PASSWORD_TEMPLATE="$REPO_ROOT/playbooks/sample_vars/passwords.yml"

while IFS= read -r line; do
    # Make a random string. SECRET_KEY's should be longer.
    length=35
    if [[ $line == *SECRET_KEY* ]]; then
        length=100
    fi
    REPLACE=$(python3 -c 'import secrets, string, sys; alphabet=string.ascii_letters+string.digits; print("".join(secrets.choice(alphabet) for _ in range(int(sys.argv[1]))))' "$length")
    # Change "!!null"-to-end-of-line to the password.
    echo "$line" | sed "s/\!\!null.*/\'$REPLACE\'/"
done < "$PASSWORD_TEMPLATE" > my-passwords.yml

ANALYTICS_TOKEN=$(python3 -c 'import secrets; print(secrets.token_hex(20))')
ANALYTICS_DEFAULT_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')
ANALYTICS_REPORTS_PASSWORD=$(python3 -c 'import secrets; print(secrets.token_urlsafe(32))')

cat >> my-passwords.yml <<EOF

# Analytics API and Insights must share this token.
ANALYTICS_API_AUTH_TOKEN: '$ANALYTICS_TOKEN'
ANALYTICS_API_USERS:
  insights: '$ANALYTICS_TOKEN'
INSIGHTS_DATA_API_AUTH_TOKEN: '$ANALYTICS_TOKEN'
ANALYTICS_API_DEFAULT_PASSWORD: '$ANALYTICS_DEFAULT_PASSWORD'
ANALYTICS_API_REPORTS_PASSWORD: '$ANALYTICS_REPORTS_PASSWORD'
EOF

chmod 600 my-passwords.yml
