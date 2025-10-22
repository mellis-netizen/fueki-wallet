# Fueki Mobile Wallet - User Guide

## Table of Contents
1. [Getting Started](#getting-started)
2. [Creating a Wallet](#creating-a-wallet)
3. [Backup and Recovery](#backup-and-recovery)
4. [Managing Multiple Wallets](#managing-multiple-wallets)
5. [Sending Cryptocurrency](#sending-cryptocurrency)
6. [Receiving Cryptocurrency](#receiving-cryptocurrency)
7. [Transaction History](#transaction-history)
8. [Network Settings](#network-settings)
9. [Security Features](#security-features)
10. [Troubleshooting](#troubleshooting)
11. [FAQ](#faq)

---

## Getting Started

### System Requirements

- **iOS**: 13.0 or later
- **Android**: 8.0 (API level 26) or later
- **Storage**: Minimum 100MB free space
- **Internet**: Active internet connection required

### Installation

#### iOS (App Store)
1. Open App Store
2. Search for "Fueki Wallet"
3. Tap "Get" or "Download"
4. Wait for installation to complete
5. Open the app

#### Android (Google Play)
1. Open Google Play Store
2. Search for "Fueki Wallet"
3. Tap "Install"
4. Wait for installation to complete
5. Open the app

### First Launch

When you first open Fueki Wallet, you'll see:

1. **Welcome Screen**
   - Introduction to Fueki Wallet
   - Overview of features

2. **Terms of Service**
   - Read and accept terms
   - Privacy policy

3. **Setup Options**
   - Create new wallet
   - Restore existing wallet
   - Import wallet

---

## Creating a Wallet

### Step-by-Step Guide

#### 1. Choose "Create New Wallet"

Tap the "Create New Wallet" button on the home screen.

#### 2. Set Up Security

**Choose Authentication Method:**
- PIN (4-6 digits)
- Biometric (Face ID / Fingerprint)
- Pattern lock

**Security Tips:**
- Use strong, unique PIN
- Enable biometric authentication
- Don't share your PIN

#### 3. Generate Recovery Phrase

Your wallet will generate a 12-word or 24-word recovery phrase.

**Important**:
- Write down your recovery phrase
- Keep it in a safe place
- Never share it with anyone
- Never store it digitally

**Example Recovery Phrase:**
```
abandon ability able about above absent
absorb abstract absurd abuse access accident
```

#### 4. Verify Recovery Phrase

You'll be asked to verify your recovery phrase by selecting words in the correct order.

This ensures you've written it down correctly.

#### 5. Wallet Created!

Your wallet is now ready to use. You'll see:
- Your Bitcoin address
- Your Ethereum address
- Your balance (initially 0)

---

## Backup and Recovery

### Creating a Backup

#### Recovery Phrase Backup

1. Go to Settings → Security
2. Tap "Show Recovery Phrase"
3. Authenticate (PIN/Biometric)
4. Write down your 12/24-word phrase
5. Store safely offline

**Storage Recommendations:**
- Paper: Write clearly, store in safe
- Metal plate: Engrave for durability
- Safety deposit box: Bank storage
- Split storage: Divide across locations

**Never Store:**
- In cloud storage
- In email or messages
- On your computer
- In photos on your phone

#### Encrypted Backup

Some wallets support encrypted backups:

1. Go to Settings → Backup
2. Tap "Create Encrypted Backup"
3. Set backup password
4. Save backup file
5. Store backup securely

### Restoring a Wallet

#### From Recovery Phrase

1. Launch Fueki Wallet
2. Choose "Restore Wallet"
3. Select "Recovery Phrase"
4. Enter your 12/24-word phrase
5. Set new PIN/Biometric
6. Wallet restored!

#### From Encrypted Backup

1. Launch Fueki Wallet
2. Choose "Restore Wallet"
3. Select "Encrypted Backup"
4. Choose backup file
5. Enter backup password
6. Set new PIN/Biometric
7. Wallet restored!

### Testing Your Backup

**Before sending large amounts:**
1. Create wallet
2. Backup recovery phrase
3. Send small test amount
4. Delete and restore wallet
5. Verify funds appear

---

## Managing Multiple Wallets

### Creating Additional Wallets

Fueki Wallet supports multiple accounts:

1. Go to Settings → Accounts
2. Tap "Add Account"
3. Choose account type:
   - New account (new recovery phrase)
   - Derived account (same recovery phrase)
4. Set account name
5. Account created!

### Switching Between Wallets

1. Tap wallet name at top of screen
2. Select wallet from dropdown
3. View balances and transactions

### Account Types

#### HD Wallet Accounts

Derived from the same recovery phrase:
- Account 0: m/44'/0'/0'/0/0
- Account 1: m/44'/0'/1'/0/0
- Account 2: m/44'/0'/2'/0/0

**Advantages:**
- Single backup phrase
- Easy to manage
- Hierarchical organization

#### Independent Wallets

Each has its own recovery phrase:
- Separate backup required
- Complete isolation
- Maximum privacy

---

## Sending Cryptocurrency

### Sending Bitcoin

1. **Select Bitcoin Wallet**
   - Tap "Bitcoin" on home screen

2. **Tap "Send"**
   - Enter recipient address
   - Or scan QR code

3. **Enter Amount**
   - Amount in BTC
   - Or equivalent in fiat currency
   - Check you have sufficient balance

4. **Review Transaction**
   - Verify recipient address
   - Check amount
   - Review network fee
   - Select fee priority:
     - Low (slow, cheap)
     - Medium (normal)
     - High (fast, expensive)

5. **Confirm Transaction**
   - Authenticate (PIN/Biometric)
   - Transaction signed
   - Broadcasting to network

6. **Transaction Sent**
   - View transaction ID
   - Monitor confirmation status
   - Receive notification when confirmed

### Sending Ethereum

1. **Select Ethereum Wallet**
   - Tap "Ethereum" on home screen

2. **Tap "Send"**
   - Enter recipient address
   - Or scan QR code

3. **Enter Amount**
   - Amount in ETH
   - Or equivalent in fiat currency
   - Check you have sufficient balance

4. **Review Gas Fees**
   - Gas limit
   - Gas price (or EIP-1559 fees)
   - Total transaction cost
   - Fee priority:
     - Low (slow, cheap)
     - Medium (normal)
     - High (fast, expensive)

5. **Confirm Transaction**
   - Authenticate (PIN/Biometric)
   - Transaction signed
   - Broadcasting to network

6. **Transaction Sent**
   - View transaction hash
   - Monitor confirmation status
   - Receive notification when confirmed

### Safety Tips

**Before Sending:**
- [ ] Double-check recipient address
- [ ] Verify amount is correct
- [ ] Ensure sufficient balance for fees
- [ ] Start with small test transaction
- [ ] Verify network (mainnet/testnet)

**Address Verification:**
- Compare first and last characters
- Use QR codes when possible
- Verify through multiple channels
- Save frequently used addresses

---

## Receiving Cryptocurrency

### Receiving Bitcoin

1. **Open Bitcoin Wallet**
   - Tap "Bitcoin" on home screen

2. **Tap "Receive"**
   - Your Bitcoin address displayed
   - QR code shown

3. **Share Address**
   - Copy address to clipboard
   - Share QR code
   - Send via message/email

4. **Wait for Transaction**
   - Monitor for incoming transaction
   - Receive notification
   - Wait for confirmations:
     - 1 confirmation: Low risk
     - 3 confirmations: Medium risk
     - 6 confirmations: High security

### Receiving Ethereum

1. **Open Ethereum Wallet**
   - Tap "Ethereum" on home screen

2. **Tap "Receive"**
   - Your Ethereum address displayed
   - QR code shown
   - Checksummed address (mixed case)

3. **Share Address**
   - Copy address to clipboard
   - Share QR code
   - Send via message/email

4. **Wait for Transaction**
   - Monitor for incoming transaction
   - Receive notification
   - Wait for confirmations:
     - 1 confirmation: Low risk
     - 12 confirmations: High security

### Address Best Practices

**Security:**
- Verify address before sharing
- Use QR codes to prevent typos
- Don't reuse addresses (Bitcoin)
- Check address checksum (Ethereum)

**Privacy:**
- Use new address for each payment (Bitcoin)
- Consider separate wallets for different purposes
- Don't share addresses publicly unless necessary

---

## Transaction History

### Viewing Transactions

1. **Open Wallet**
   - Select Bitcoin or Ethereum

2. **View Transaction List**
   - Recent transactions displayed
   - Pending transactions at top
   - Confirmed transactions below

3. **Transaction Details**
   - Tap any transaction
   - View details:
     - Transaction ID/Hash
     - Amount
     - Fee
     - Timestamp
     - Confirmations
     - Block number
     - From/To addresses

### Transaction Status

**Pending** ⏳
- Waiting for network confirmation
- Can take minutes to hours
- Depends on network congestion and fee

**Confirming** ⚠️
- Included in block
- Accumulating confirmations
- Bitcoin: 1-6 confirmations needed
- Ethereum: 1-12 confirmations needed

**Confirmed** ✅
- Fully confirmed
- Irreversible
- Funds available

**Failed** ❌
- Transaction rejected
- Insufficient gas (Ethereum)
- Double-spend attempt
- Invalid transaction

### Filtering Transactions

- **All**: Show all transactions
- **Sent**: Only outgoing transactions
- **Received**: Only incoming transactions
- **Pending**: Unconfirmed transactions
- **Failed**: Failed transactions

### Exporting History

1. Go to Settings → Export
2. Select wallet
3. Choose format:
   - CSV
   - PDF
   - JSON
4. Select date range
5. Tap "Export"
6. Save or share file

---

## Network Settings

### Switching Networks

#### Bitcoin

1. Go to Settings → Networks
2. Select Bitcoin
3. Choose network:
   - **Mainnet**: Real Bitcoin, real value
   - **Testnet**: Test Bitcoin, no value

#### Ethereum

1. Go to Settings → Networks
2. Select Ethereum
3. Choose network:
   - **Mainnet**: Real Ether, real value
   - **Sepolia**: Test Ether, no value

**Warning**: Testnet coins have no value. Don't send mainnet funds to testnet addresses!

### Custom RPC Endpoints

For advanced users:

1. Go to Settings → Networks → Advanced
2. Select network
3. Tap "Add Custom Endpoint"
4. Enter endpoint URL
5. Test connection
6. Save

**Security Warning**: Only use trusted RPC endpoints. Malicious endpoints can:
- Track your transactions
- Provide false balance information
- Censor transactions

---

## Security Features

### Authentication

#### PIN Code

Set up in Settings → Security → PIN:
- 4-6 digit code
- Required for transactions
- Auto-lock timeout configurable

#### Biometric Authentication

Enable in Settings → Security → Biometric:
- **iOS**: Face ID or Touch ID
- **Android**: Fingerprint or Face Unlock
- Faster than PIN
- More convenient

### Auto-Lock

Configure in Settings → Security → Auto-Lock:
- Immediate
- 1 minute
- 5 minutes
- 15 minutes
- Never (not recommended)

### Security Notifications

Enable in Settings → Security → Notifications:
- Transaction sent
- Transaction received
- Login from new device
- Settings changed
- Backup reminder

### Two-Factor Authentication (Coming Soon)

Additional security layer:
- SMS verification
- Authenticator app
- Email verification

---

## Troubleshooting

### Common Issues

#### Issue: Transaction Stuck/Pending

**Bitcoin:**
- Wait longer (can take hours during congestion)
- Check transaction fee paid
- Use transaction accelerator service
- Consider Replace-By-Fee (RBF) if enabled

**Ethereum:**
- Wait longer
- Check gas price paid
- Try speeding up transaction (higher gas price)
- Consider canceling transaction (replace with 0 ETH to self)

#### Issue: Balance Not Updating

**Solutions:**
1. Pull down to refresh
2. Check network connection
3. Switch RPC endpoint
4. Restart app
5. Check block explorer to verify transaction

#### Issue: Cannot Send Transaction

**Check:**
- Sufficient balance for amount + fees
- Valid recipient address
- Network connection
- Not on testnet when trying to send mainnet funds
- Wallet not locked

#### Issue: Recovery Phrase Not Working

**Verify:**
- All words spelled correctly
- Words in correct order
- Using correct phrase (12 or 24 words)
- No extra spaces
- Correct network (mainnet/testnet)

#### Issue: App Crashes

**Try:**
1. Force close and restart app
2. Clear app cache
3. Restart device
4. Check for app updates
5. Reinstall app (backup first!)

### Getting Help

1. **In-App Support**
   - Settings → Help & Support
   - Submit ticket
   - View FAQs

2. **Documentation**
   - https://docs.fueki.io

3. **Community**
   - Discord: discord.gg/fueki
   - Telegram: t.me/fuekiwallet
   - Twitter: @fuekiwallet

4. **Email Support**
   - support@fueki.io
   - Response within 24 hours

---

## FAQ

### General

**Q: Is Fueki Wallet free?**
A: Yes, the app is free to download and use. You only pay network transaction fees.

**Q: Does Fueki Wallet have access to my funds?**
A: No. Fueki is a non-custodial wallet. You control your private keys. We never have access to your funds.

**Q: What cryptocurrencies are supported?**
A: Currently Bitcoin and Ethereum. More chains coming soon!

**Q: Can I use Fueki on multiple devices?**
A: Yes, restore your wallet using your recovery phrase on any device.

### Security

**Q: What if I lose my phone?**
A: Your funds are safe. Restore your wallet on a new device using your recovery phrase.

**Q: What if I lose my recovery phrase?**
A: Unfortunately, your funds cannot be recovered. This is why backup is crucial!

**Q: Can Fueki reset my PIN/recovery phrase?**
A: No. We cannot recover your PIN or recovery phrase. Keep them safe!

**Q: Is biometric authentication secure?**
A: Yes, but it's only a convenience layer. Your recovery phrase is the ultimate security.

### Transactions

**Q: How long do transactions take?**
A:
- Bitcoin: 10 minutes to several hours
- Ethereum: 15 seconds to several minutes
- Depends on network congestion and fees paid

**Q: Can I cancel a transaction?**
A: Once broadcast, Bitcoin transactions cannot be canceled. Ethereum transactions can sometimes be replaced before confirmation.

**Q: Why are fees so high?**
A: Network fees vary based on:
- Network congestion
- Transaction complexity
- Speed requirement (faster = higher fee)

**Q: What happens if I send to wrong address?**
A: Cryptocurrency transactions are irreversible. Always double-check addresses!

### Wallet

**Q: Can I have multiple wallets?**
A: Yes, you can create multiple accounts in the app.

**Q: Do I need separate recovery phrases?**
A: No, derived accounts use the same recovery phrase. Independent wallets need separate phrases.

**Q: Can I import wallet from other apps?**
A: Yes, using recovery phrase or private key (coming soon).

**Q: How do I delete a wallet?**
A: Settings → Accounts → Select account → Delete. Make sure to backup first!

---

## Best Practices

### Security Checklist

- [ ] Recovery phrase written down and stored safely
- [ ] Strong PIN set
- [ ] Biometric authentication enabled
- [ ] Auto-lock configured
- [ ] Security notifications enabled
- [ ] App updated to latest version
- [ ] Device lock screen enabled
- [ ] No suspicious apps installed

### Transaction Checklist

- [ ] Recipient address verified
- [ ] Amount double-checked
- [ ] Sufficient balance including fees
- [ ] Network verified (mainnet/testnet)
- [ ] Test transaction sent first (for large amounts)
- [ ] Transaction confirmed successfully

### Backup Checklist

- [ ] Recovery phrase written on paper
- [ ] Stored in secure location
- [ ] Not stored digitally
- [ ] Tested recovery process
- [ ] Multiple copies in different locations
- [ ] Protected from fire/water damage

---

## Glossary

**Address**: Your public identifier for receiving cryptocurrency
**Private Key**: Secret key that controls your funds
**Recovery Phrase**: 12 or 24 words that can restore your wallet
**Transaction Fee**: Network fee for processing transactions
**Confirmation**: Verification that transaction is included in blockchain
**Gas**: Ethereum transaction fee unit
**Satoshi**: Smallest Bitcoin unit (0.00000001 BTC)
**Wei**: Smallest Ethereum unit (0.000000000000000001 ETH)
**Mainnet**: Live blockchain with real value
**Testnet**: Test blockchain with no real value

---

## Contact and Support

**Website**: https://fueki.io
**Documentation**: https://docs.fueki.io
**Support Email**: support@fueki.io
**Discord**: discord.gg/fueki
**Twitter**: @fuekiwallet

---

**Last Updated**: 2025-10-22
**Version**: 1.0.0
