// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

// //           _____                    _____                   _______                   _____            _____                    _____                    _____                    _____
// //          /\    \                  /\    \                 /::\    \                 /\    \          /\    \                  /\    \                  /\    \                  /\    \
// //         /::\    \                /::\____\               /::::\    \               /::\____\        /::\    \                /::\____\                /::\    \                /::\    \
// //        /::::\    \              /::::|   |              /::::::\    \             /:::/    /       /::::\    \              /:::/    /               /::::\    \              /::::\    \
// //       /::::::\    \            /:::::|   |             /::::::::\    \           /:::/    /       /::::::\    \            /:::/   _/___            /::::::\    \            /::::::\    \
// //      /:::/\:::\    \          /::::::|   |            /:::/~~\:::\    \         /:::/    /       /:::/\:::\    \          /:::/   /\    \          /:::/\:::\    \          /:::/\:::\    \
// //     /:::/__\:::\    \        /:::/|::|   |           /:::/    \:::\    \       /:::/    /       /:::/__\:::\    \        /:::/   /::\____\        /:::/__\:::\    \        /:::/__\:::\    \
// //     \:::\   \:::\    \      /:::/ |::|   |          /:::/    / \:::\    \     /:::/    /        \:::\   \:::\    \      /:::/   /:::/    /       /::::\   \:::\    \      /::::\   \:::\    \
// //   ___\:::\   \:::\    \    /:::/  |::|___|______   /:::/____/   \:::\____\   /:::/    /       ___\:::\   \:::\    \    /:::/   /:::/   _/___    /::::::\   \:::\    \    /::::::\   \:::\    \
// //  /\   \:::\   \:::\    \  /:::/   |::::::::\    \ |:::|    |     |:::|    | /:::/    /       /\   \:::\   \:::\    \  /:::/___/:::/   /\    \  /:::/\:::\   \:::\    \  /:::/\:::\   \:::\____\
// // /::\   \:::\   \:::\____\/:::/    |:::::::::\____\|:::|____|     |:::|    |/:::/____/       /::\   \:::\   \:::\____\|:::|   /:::/   /::\____\/:::/  \:::\   \:::\____\/:::/  \:::\   \:::|    |
// // \:::\   \:::\   \::/    /\::/    / ~~~~~/:::/    / \:::\    \   /:::/    / \:::\    \       \:::\   \:::\   \::/    /|:::|__/:::/   /:::/    /\::/    \:::\  /:::/    /\::/    \:::\  /:::|____|
// //  \:::\   \:::\   \/____/  \/____/      /:::/    /   \:::\    \ /:::/    /   \:::\    \       \:::\   \:::\   \/____/  \:::\/:::/   /:::/    /  \/____/ \:::\/:::/    /  \/_____/\:::\/:::/    /
// //   \:::\   \:::\    \                  /:::/    /     \:::\    /:::/    /     \:::\    \       \:::\   \:::\    \       \::::::/   /:::/    /            \::::::/    /            \::::::/    /
// //    \:::\   \:::\____\                /:::/    /       \:::\__/:::/    /       \:::\    \       \:::\   \:::\____\       \::::/___/:::/    /              \::::/    /              \::::/    /
// //     \:::\  /:::/    /               /:::/    /         \::::::::/    /         \:::\    \       \:::\  /:::/    /        \:::\__/:::/    /               /:::/    /                \::/____/
// //      \:::\/:::/    /               /:::/    /           \::::::/    /           \:::\    \       \:::\/:::/    /          \::::::::/    /               /:::/    /                  ~~
// //       \::::::/    /               /:::/    /             \::::/    /             \:::\    \       \::::::/    /            \::::::/    /               /:::/    /
// //        \::::/    /               /:::/    /               \::/____/               \:::\____\       \::::/    /              \::::/    /               /:::/    /
// //         \::/    /                \::/    /                 ~~                      \::/    /        \::/    /                \::/____/                \::/    /
// //          \/____/                  \/____/                                           \/____/          \/____/                  ~~                       \/____/

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
// import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
// import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import "@openzeppelin/contracts/utils/introspection/ERC165.sol";

// import "../token/ANFTReceiver2.sol";

// import "./diamond/Diamond.sol";
// import "./diamond/facets/OwnershipFacet.sol";

// contract SmolSweepSwapper is Diamond, ANFTReceiver2, OwnershipModifers {
//   using SafeERC20 for IERC20;

//   constructor(address _contractOwner, address _diamondCutFacet)
//     Diamond(_contractOwner, _diamondCutFacet)
//   {}

//   function approveERC20TokenToContract(
//     IERC20 _token,
//     address _contract,
//     uint256 _amount
//   ) external onlyOwner {
//     _token.safeApprove(address(_contract), uint256(_amount));
//   }

//   // rescue functions
//   // those have not been tested yet
//   function transferETHTo(address payable _to, uint256 _amount)
//     external
//     onlyOwner
//   {
//     _to.transfer(_amount);
//   }

//   function transferERC20TokenTo(
//     IERC20 _token,
//     address _address,
//     uint256 _amount
//   ) external onlyOwner {
//     _token.safeTransfer(address(_address), uint256(_amount));
//   }

//   function transferERC721To(
//     IERC721 _token,
//     address _to,
//     uint256 _tokenId
//   ) external onlyOwner {
//     _token.safeTransferFrom(address(this), _to, _tokenId);
//   }

//   function transferERC1155To(
//     IERC1155 _token,
//     address _to,
//     uint256[] calldata _tokenIds,
//     uint256[] calldata _amounts,
//     bytes calldata _data
//   ) external onlyOwner {
//     _token.safeBatchTransferFrom(
//       address(this),
//       _to,
//       _tokenIds,
//       _amounts,
//       _data
//     );
//   }
// }
