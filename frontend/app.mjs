import {domain, clientId, apiURL} from "./config.js";

const sha256 = async (str) => {
	return await crypto.subtle.digest("SHA-256", new TextEncoder().encode(str));
};

const generateNonce = async () => {
	const hash = await sha256(crypto.getRandomValues(new Uint32Array(4)).toString());
	// https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest
	const hashArray = Array.from(new Uint8Array(hash));
	return hashArray.map(b => b.toString(16).padStart(2, "0")).join("");
};

const base64URLEncode = (string) => {
	return btoa(String.fromCharCode.apply(null, new Uint8Array(string)))
		.replace(/\+/g, "-")
		.replace(/\//g, "_")
		.replace(/=+$/, "")
};

const getOpenIdConfiguration = async (domain) => {
	const res = await fetch(`https://${domain}/.well-known/openid-configuration`);
	if (!res.ok) {
		throw res;
	}
	return res.json();
}

const redirectToLogin = async () => {
	const state = await generateNonce();
	const codeVerifier = await generateNonce();
	sessionStorage.setItem(`codeVerifier-${state}`, codeVerifier);
	const codeChallenge = base64URLEncode(await sha256(codeVerifier));
	const {authorization_endpoint} = await getOpenIdConfiguration(domain);
	window.location = `${authorization_endpoint}?response_type=code&client_id=${clientId}&state=${state}&code_challenge_method=S256&code_challenge=${codeChallenge}&redirect_uri=${window.location.origin}&scope=openid`;
};

const init = async (tokens) => {
	document.querySelector("#logging-in").innerText = "Logged in";
	const res = await fetch(apiURL, {method: "POST", body:JSON.stringify({'query': "query MyQuery {user}", operation: "MyQuery"}),headers: {Authorization: tokens.id_token}});
	if (!res.ok) {
		throw res;
	}

	const result = await res.json();
	document.querySelector("#result").innerText = JSON.stringify(JSON.parse(result.data.user), undefined, 2);
}

const searchParams = new URL(location).searchParams;

if (searchParams.get("code") !== null) {
	window.history.replaceState({}, document.title, "/");
	const state = searchParams.get("state");
	const codeVerifier = sessionStorage.getItem(`codeVerifier-${state}`);
	sessionStorage.removeItem(`codeVerifier-${state}`);
	if (codeVerifier === null) {
		throw new Error("Unexpected code");
	}
	const {token_endpoint} = await getOpenIdConfiguration(domain);
	const res = await fetch(token_endpoint, {
		method: "POST",
		headers: new Headers({"content-type": "application/x-www-form-urlencoded"}),
		body: Object.entries({
			"grant_type": "authorization_code",
			"client_id": clientId,
			"code": searchParams.get("code"),
			"code_verifier": codeVerifier,
			"redirect_uri": window.location.origin,
		}).map(([k, v]) => `${k}=${v}`).join("&"),
	});
	if (!res.ok) {
		throw new Error(await res.json());
	}
	const tokens = await res.json();
	init(tokens);
}else {
	redirectToLogin();
}
