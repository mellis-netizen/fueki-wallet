#include "include/CSecp256k1.h"
#include <string.h>

// Create context with both sign and verify capabilities
secp256k1_context* secp256k1_context_create_sign_verify(void) {
    return secp256k1_context_create(SECP256K1_CONTEXT_SIGN | SECP256K1_CONTEXT_VERIFY);
}

// Helper to create public key from private key
int secp256k1_pubkey_create_helper(
    const secp256k1_context* ctx,
    unsigned char* output,
    size_t* output_len,
    const unsigned char* private_key,
    int compressed
) {
    secp256k1_pubkey pubkey;

    // Create public key
    if (!secp256k1_ec_pubkey_create(ctx, &pubkey, private_key)) {
        return 0;
    }

    // Serialize to compressed or uncompressed format
    unsigned int flags = compressed ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED;
    if (!secp256k1_ec_pubkey_serialize(ctx, output, output_len, &pubkey, flags)) {
        return 0;
    }

    return 1;
}

// Helper to parse public key
int secp256k1_pubkey_parse_helper(
    const secp256k1_context* ctx,
    secp256k1_pubkey* pubkey,
    const unsigned char* input,
    size_t input_len
) {
    return secp256k1_ec_pubkey_parse(ctx, pubkey, input, input_len);
}

// Helper to sign message (deterministic RFC6979)
int secp256k1_ecdsa_sign_helper(
    const secp256k1_context* ctx,
    unsigned char* output,
    const unsigned char* msg32,
    const unsigned char* private_key
) {
    secp256k1_ecdsa_signature sig;

    // Sign with deterministic nonce (RFC6979)
    if (!secp256k1_ecdsa_sign(ctx, &sig, msg32, private_key, NULL, NULL)) {
        return 0;
    }

    // Serialize to compact format (64 bytes: r || s)
    secp256k1_ecdsa_signature_serialize_compact(ctx, output, &sig);

    return 1;
}

// Helper to create recoverable signature
int secp256k1_ecdsa_sign_recoverable_helper(
    const secp256k1_context* ctx,
    unsigned char* output,
    int* recid,
    const unsigned char* msg32,
    const unsigned char* private_key
) {
    secp256k1_ecdsa_recoverable_signature sig;

    // Sign with recovery information
    if (!secp256k1_ecdsa_sign_recoverable(ctx, &sig, msg32, private_key, NULL, NULL)) {
        return 0;
    }

    // Serialize to compact format with recovery id
    secp256k1_ecdsa_recoverable_signature_serialize_compact(ctx, output, recid, &sig);

    return 1;
}

// Helper to verify signature
int secp256k1_ecdsa_verify_helper(
    const secp256k1_context* ctx,
    const unsigned char* sig64,
    const unsigned char* msg32,
    const unsigned char* pubkey_data,
    size_t pubkey_len
) {
    secp256k1_ecdsa_signature sig;
    secp256k1_pubkey pubkey;

    // Parse signature
    if (!secp256k1_ecdsa_signature_parse_compact(ctx, &sig, sig64)) {
        return 0;
    }

    // Parse public key
    if (!secp256k1_ec_pubkey_parse(ctx, &pubkey, pubkey_data, pubkey_len)) {
        return 0;
    }

    // Verify signature
    return secp256k1_ecdsa_verify(ctx, &sig, msg32, &pubkey);
}

// Helper to recover public key from signature
int secp256k1_ecdsa_recover_helper(
    const secp256k1_context* ctx,
    unsigned char* output,
    size_t* output_len,
    const unsigned char* sig64,
    int recid,
    const unsigned char* msg32,
    int compressed
) {
    secp256k1_ecdsa_recoverable_signature sig;
    secp256k1_pubkey pubkey;

    // Parse recoverable signature
    if (!secp256k1_ecdsa_recoverable_signature_parse_compact(ctx, &sig, sig64, recid)) {
        return 0;
    }

    // Recover public key
    if (!secp256k1_ecdsa_recover(ctx, &pubkey, &sig, msg32)) {
        return 0;
    }

    // Serialize public key
    unsigned int flags = compressed ? SECP256K1_EC_COMPRESSED : SECP256K1_EC_UNCOMPRESSED;
    if (!secp256k1_ec_pubkey_serialize(ctx, output, output_len, &pubkey, flags)) {
        return 0;
    }

    return 1;
}

// Helper to add tweak to private key
int secp256k1_ec_privkey_tweak_add_helper(
    const secp256k1_context* ctx,
    unsigned char* seckey,
    const unsigned char* tweak
) {
    return secp256k1_ec_seckey_tweak_add(ctx, seckey, tweak);
}

// Helper to multiply private key by tweak
int secp256k1_ec_privkey_tweak_mul_helper(
    const secp256k1_context* ctx,
    unsigned char* seckey,
    const unsigned char* tweak
) {
    return secp256k1_ec_seckey_tweak_mul(ctx, seckey, tweak);
}

// Helper to negate private key
int secp256k1_ec_privkey_negate_helper(
    const secp256k1_context* ctx,
    unsigned char* seckey
) {
    return secp256k1_ec_seckey_negate(ctx, seckey);
}

// Helper to verify private key is valid
int secp256k1_ec_seckey_verify_helper(
    const secp256k1_context* ctx,
    const unsigned char* seckey
) {
    return secp256k1_ec_seckey_verify(ctx, seckey);
}

// Helper to verify public key is valid
int secp256k1_ec_pubkey_verify_helper(
    const secp256k1_context* ctx,
    const unsigned char* pubkey_data,
    size_t pubkey_len
) {
    secp256k1_pubkey pubkey;
    return secp256k1_ec_pubkey_parse(ctx, &pubkey, pubkey_data, pubkey_len);
}
