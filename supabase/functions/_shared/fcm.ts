// Shared FCM HTTP v1 API helper used by all notification Edge Functions.
// Requires the FIREBASE_SERVICE_ACCOUNT secret (full service account JSON string).

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

// Convert a PEM private key to a DER ArrayBuffer.
function pemToDer(pem: string): ArrayBuffer {
  const b64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');
  const binary = atob(b64);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes.buffer;
}

// Base64url-encode a string or ArrayBuffer.
function b64url(input: string | ArrayBuffer): string {
  const str =
    typeof input === 'string'
      ? input
      : String.fromCharCode(...new Uint8Array(input));
  return btoa(str).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
}

// Sign a JWT with the service account private key (RS256) and exchange it
// for a short-lived Google OAuth2 access token.
export async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const payload = b64url(
    JSON.stringify({
      iss: sa.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    })
  );

  const signingInput = `${header}.${payload}`;

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    pemToDer(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const jwt = `${signingInput}.${b64url(signature)}`;

  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  if (!resp.ok) {
    throw new Error(`OAuth2 token exchange failed: ${await resp.text()}`);
  }

  const { access_token } = await resp.json();
  return access_token as string;
}

// Send a single FCM message via the HTTP v1 API.
// Silently logs errors per-token so one bad token doesn't abort the batch.
export async function sendFcm(
  accessToken: string,
  projectId: string,
  token: string,
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  const resp = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          android: { priority: 'high' },
          data,
        },
      }),
    }
  );

  if (!resp.ok) {
    console.error(`[FCM] Failed for token ...${token.slice(-8)}: ${await resp.text()}`);
  }
}

// Send to many tokens in parallel, collecting per-token errors internally.
export async function sendFcmBatch(
  accessToken: string,
  projectId: string,
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string> = {}
): Promise<void> {
  await Promise.all(
    tokens.map((t) => sendFcm(accessToken, projectId, t, title, body, data))
  );
}
