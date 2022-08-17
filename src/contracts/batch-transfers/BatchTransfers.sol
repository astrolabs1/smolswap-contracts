// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract BatchTransfer {
  struct TransferItem {
    address nftAddress;
    uint256 tokenId;
  }

  constructor() {}

  /** @notice Transfers given ERC-721 items from sender to recipient.
     @param  items         Struct containing all nftAddress and tokenId pairs to send
     @param  recipient     Sending to
    */
  function batchTransfer(TransferItem[] calldata items, address recipient)
    external
  {
    for (uint16 i; i < items.length; i++) {
      IERC721(items[i].nftAddress).safeTransferFrom(
        msg.sender,
        recipient,
        items[i].tokenId
      );
    }
  }
}

contract BatchTransferV2 {
  struct TransferItem {
    address nftAddress;
    uint256[] tokenIds;
  }

  constructor() {}

  /** @notice Transfers given ERC-721 items from sender to recipient.
     @param  items         Struct containing all nftAddress and tokenId pairs to send
     @param  recipient     Sending to
    */
  function batchTransfer(TransferItem[] calldata items, address recipient)
    external
  {
    uint16 i = 0;
    for (; i < items.length; ) {
      uint16 j = 0;
      for (; j < items[i].tokenIds.length; ) {
        IERC721(items[i].nftAddress).safeTransferFrom(
          msg.sender,
          recipient,
          items[i].tokenIds[j]
        );
        unchecked {
          ++j;
        }
      }
      unchecked {
        ++i;
      }
    }
  }
}
