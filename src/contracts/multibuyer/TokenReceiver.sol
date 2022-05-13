// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";

abstract contract TokenReceiver is IERC721Receiver, IERC1155Receiver {
    /**
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * Always returns `IERC1155Receiver.onERC1155ReceivedFrom.selector`.
     */
     function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    // function onERC1155Received(
    //     address operator,
    //     address from,
    //     uint256 id,
    //     uint256 value,
    //     bytes calldata data
    // ) public virtual override returns (bytes4) {
    //     return this.onERC1155Received.selector;
    // }



    /**
     * Always returns `IERC1155Receiver.onERC1155BatchReceived.selector`.
     */
    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    // function onERC1155BatchReceived(
    //     address operator,
    //     address from,
    //     uint256[] calldata ids,
    //     uint256[] calldata values,
    //     bytes calldata data
    // ) public virtual override returns (bytes4) {
    //     return this.onERC1155BatchReceived.selector;
    // }
}