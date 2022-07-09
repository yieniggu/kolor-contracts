![Kolor logo](/assets/kolor_logo_white.jpeg "Kolor logo")

# Kolor Smart Contracts Repository

This repository contains the **core contracts** used in Kolor's dapp. The contracts comes both in .sol version and .json for their corresponding abis.

## Kolor Land Interface Contract ([IKolorLandNFT.sol](https://github.com/yieniggu/kolor-contracts/blob/main/contracts/IKolorLandNFT.sol))

This contract defines a series of function that are used by our NFT and Marketplace contracts. We made this to follow best practices defined internally by our team and preserve the interactions needed between these two contracts and defined in our processes.

## Kolor Land NFT Contract ([KolorLandNFT.sol](https://github.com/yieniggu/kolor-contracts/blob/main/contracts/KolorLandNFT.sol))

Our NFT-type contract. Although extends from the classic ERC-721 we are the one and only owner of each minted NFT. We chose this standard in order to utilize its functionalities and build our architecture on top of them. Contains all the required metadata for our lands such as owner information, species and location.

[Check it on explorer](https://explorer.celo.org/address/0x2fE59334E3AA01C024d8b87DDc59067E3455217C/contracts)

## Kolor Marketplace Contract ([KolorMarketplace.sol](https://github.com/yieniggu/kolor-contracts/blob/main/contracts/KolorMarketplace.sol))

Our Marketplace contract. Contains the logic that allows a land to be available for purchase from our users. Interacts with the land NFT contract and the land token contract to publish land assets.


[Check it on explorer](https://explorer.celo.org/address/0x960bBa826ed09A227A3c913351aDd41E12640b5c/contracts)

## Kolor Land Token ([KolorLandToken.sol](https://github.com/yieniggu/kolor-contracts/blob/main/contracts/KolorMarketplace.sol))

Our land token contract. Allow us to mint our own tokens. However liquidity can't be added on any dex for this tokens, as they're not ERC-20 like tokens. Instead they can be exchanged in our marketplace, or other marketplaces that provides an api to interact with the contract methods. Still, implements a series of functions and variables that make the tokens work just as ERC-20 but without the ability to provide liquidity.

[Check it on explorer](https://explorer.celo.org/address/0x6390AddE3fDa14DD90cb0ec4A12bd232d8c0fCeC/contracts)
