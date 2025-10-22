#ifndef CSecp256k1_h
#define CSecp256k1_h

#include <stdint.h>
#include <stdlib.h>

// Re-export secp256k1 C library with Swift-friendly interface
#include "secp256k1.h"
#include "secp256k1_recovery.h"
#include "secp256k1_extrakeys.h"
#include "secp256k1_schnorrsig.h"

// Helper functions for Swift interop
#ifdef __cplusplus
extern "C" {
#endif

// Context management
secp256k1_context* secp256k1_context_create_sign_verify(void);

// Public key operations
int secp256k1_pubkey_create_helper(
    const secp256k1_context* ctx,
    unsigned char* output,
    size_t* output_len,
    const unsigned char* private_key,
    int compressed
);

int secp256k1_pubkey_parse_helper(
    const secp256k1_context* ctx,
    secp256k1_pubkey* pubkey,
    const unsigned char* input,
    size_t input_len
);

// Signing operations
int secp256k1_ecdsa_sign_helper(
    const secp256k1_context* ctx,
    unsigned char* output,
    const unsigned char* msg32,
    const unsigned char* private_key
);

int secp256k1_ecdsa_sign_recoverable_helper(
    const secp256k1_context* ctx,
    unsigned char* output,
    int* recid,
    const unsigned char* msg32,
    const unsigned char* private_key
);

// Verification operations
int secp256k1_ecdsa_verify_helper(
    const secp256k1_context* ctx,
    const unsigned char* sig64,
    const unsigned char* msg32,
    const unsigned char* pubkey_data,
    size_t pubkey_len
);

// Recovery operations
int secp256k1_ecdsa_recover_helper(
    const secp256k1_context* ctx,
    unsigned char* output,
    size_t* output_len,
    const unsigned char* sig64,
    int recid,
    const unsigned char* msg32,
    int compressed
);

// Key tweaking operations
int secp256k1_ec_privkey_tweak_add_helper(
    const secp256k1_context* ctx,
    unsigned char* seckey,
    const unsigned char* tweak
);

int secp256k1_ec_privkey_tweak_mul_helper(
    const secp256k1_context* ctx,
    unsigned char* seckey,
    const unsigned char* tweak
);

int secp256k1_ec_privkey_negate_helper(
    const secp256k1_context* ctx,
    unsigned char* seckey
);

// Validation
int secp256k1_ec_seckey_verify_helper(
    const secp256k1_context* ctx,
    const unsigned char* seckey
);

int secp256k1_ec_pubkey_verify_helper(
    const secp256k1_context* ctx,
    const unsigned char* pubkey_data,
    size_t pubkey_len
);

#ifdef __cplusplus
}
#endif

#endif /* CSecp256k1_h */
