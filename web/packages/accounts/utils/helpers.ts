// TODO: Audit this file, this can be better. e.g. do we need the Object.assign?

import { type KeyAttributes } from "ente-accounts/services/user";
import {
    boxSealOpenBytes,
    decryptBox,
    sharedCryptoWorker,
    toB64URLSafe,
} from "ente-base/crypto";
import { getData, setData, setLSUser } from "ente-shared/storage/localStorage";

export async function decryptAndStoreToken(
    keyAttributes: KeyAttributes,
    masterKey: string,
) {
    const user = getData("user");
    const { encryptedToken } = user;

    if (encryptedToken && encryptedToken.length > 0) {
        const { encryptedSecretKey, secretKeyDecryptionNonce, publicKey } =
            keyAttributes;
        const privateKey = await decryptBox(
            {
                encryptedData: encryptedSecretKey,
                nonce: secretKeyDecryptionNonce,
            },
            masterKey,
        );

        const decryptedToken = await toB64URLSafe(
            await boxSealOpenBytes(encryptedToken, { publicKey, privateKey }),
        );

        await setLSUser({
            ...user,
            token: decryptedToken,
            encryptedToken: null,
        });
    }
}

/**
 * Encrypt the user's masterKey with an intermediate kek (key encryption key)
 * derived from the passphrase (with interactive mem and ops limits) to avoid
 * saving it to local storage in plain text.
 *
 * This means that on the web user will always have to enter their passphrase to
 * access their masterKey when repopening the app in a new tab (on desktop we
 * can use OS storage, see [Note: Safe storage and interactive KEK attributes]).
 */
export async function generateAndSaveIntermediateKeyAttributes(
    passphrase: string,
    existingKeyAttributes: KeyAttributes,
    key: string,
): Promise<KeyAttributes> {
    const cryptoWorker = await sharedCryptoWorker();
    const intermediateKek = await cryptoWorker.deriveInteractiveKey(passphrase);
    const { encryptedData: encryptedKey, nonce: keyDecryptionNonce } =
        await cryptoWorker.encryptBox(key, intermediateKek.key);

    const intermediateKeyAttributes = Object.assign(existingKeyAttributes, {
        encryptedKey,
        keyDecryptionNonce,
        kekSalt: intermediateKek.salt,
        opsLimit: intermediateKek.opsLimit,
        memLimit: intermediateKek.memLimit,
    });
    setData("keyAttributes", intermediateKeyAttributes);
    return intermediateKeyAttributes;
}
