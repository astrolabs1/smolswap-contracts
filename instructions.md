1. Deploy FakeNFT.sol and mint 5 NFTs
2. Deploy Magic.sol and mint 1 000 000 000 000 * decimals()
3. Deploy TreasureNFTOracle.sol
4. Deploy TreasureMarketplace.sol
5. TransferOwnership of TreasureNFTOracle to TreasureMarketplace contract address
6. ApproveForAll for FakeNFT to TreasureMarketplace contract address
7. List NFT onto TreasureMarketplace
8. Send 1000 * decimals() magic tokens to second address
9. Switch to second address
10. Approve INFINITE magic tokens from smolswap to TreasureMarketplace contract address
11. Buy NFT on TreasureMarketplace