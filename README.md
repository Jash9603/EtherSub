# Fund Me Smart Contract

A decentralized funding platform built with Solidity and Foundry, allowing users to fund the contract with ETH while maintaining a minimum USD value requirement using Chainlink price feeds.

## 🚀 Features

- **ETH Funding**: Users can send ETH to the contract
- **Minimum USD Requirement**: Enforces a minimum funding amount of $5 USD
- **Price Feed Integration**: Uses Chainlink's price feed for accurate ETH/USD conversion
- **Owner Controls**: Only the contract owner can withdraw funds
- **Gas Optimization**: Includes both standard and gas-optimized withdrawal functions
- **Fallback Functions**: Supports both `receive()` and `fallback()` for direct ETH transfers

## 📋 Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [React.js](https://react.dev/) (for development)
- An Ethereum wallet with testnet ETH
- Chainlink Price Feed address for your network

## 🛠️ Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd foundry-fund-me
```

2. Install dependencies:
```bash
forge install
```

3. Build the contracts:
```bash
forge build
```

## 🧪 Testing

The project includes comprehensive test coverage:

### Unit Tests
```bash
forge test
```

### Gas Report
```bash
forge snapshot
```

### Test Coverage
```bash
forge coverage
```

## 📝 Contract Details

### Main Contract: `FundMe.sol`
- Manages funding and withdrawals
- Tracks funders and their contributions
- Implements owner-only withdrawal functionality
- Uses Chainlink price feeds for USD conversion

### Library: `PriceConverter.sol`
- Handles ETH to USD conversion
- Integrates with Chainlink price feeds
- Provides price conversion utilities

## 🚀 Deployment

1. Configure your environment:
   - Set up your RPC URL
   - Configure your private key
   - Set the appropriate Chainlink price feed address

2. Deploy the contract:
```bash
forge script script/DeployFundMe.s.sol --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> --broadcast
```

## 💰 Interacting with the Contract

### Funding
```bash
forge script script/Interaction.s.sol:FundFundMe --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> --broadcast
```

### Withdrawing (Owner Only)
```bash
forge script script/Interaction.s.sol:WithdrawFundMe --rpc-url <YOUR_RPC_URL> --private-key <YOUR_PRIVATE_KEY> --broadcast
```

## �� Contract Functions

### Public Functions
- `fund()`: Send ETH to the contract
- `withdraw()`: Owner can withdraw all funds
- `cheaperwithdrawl()`: Gas-optimized withdrawal function
- `getVersion()`: Get Chainlink price feed version
- `getPriceFeed()`: Get price feed address

### View Functions
- `getAddressToAmountFunded(address)`: Get amount funded by an address
- `getFunder(uint256)`: Get funder address by index
- `getOwner()`: Get contract owner address

## ⚠️ Important Notes

- Minimum funding amount is set to $5 USD
- Only the contract owner can withdraw funds
- The contract uses Chainlink's price feed for accurate ETH/USD conversion
- Gas-optimized withdrawal function available for multiple funders

## 🔗 Dependencies

- [Foundry](https://book.getfoundry.sh/)
- [Chainlink Price Feeds](https://docs.chain.link/data-feeds/price-feeds)
- [OpenZeppelin](https://www.openzeppelin.com/) (if used)

## 📚 Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [Chainlink Documentation](https://docs.chain.link/)
- [Solidity Documentation](https://docs.soliditylang.org/)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Security

- Always test thoroughly before deploying to mainnet
- Use the gas-optimized withdrawal function for multiple funders
- Ensure proper access control for owner functions
- Verify price feed addresses for your network

## 🔍 Testing Coverage

The project includes comprehensive test coverage:
- Unit tests for all contract functions
- Gas optimization tests
- Multiple funder scenario tests
- Owner access control tests

## 🛠️ Development

### Formatting
```bash
forge fmt
```

### Gas Snapshots
```bash
forge snapshot
```

### Compilation
```bash
forge build
```

## 📞 Support

For support, please open an issue in the repository or contact the maintainers.

---

Built with ❤️ using Foundry
