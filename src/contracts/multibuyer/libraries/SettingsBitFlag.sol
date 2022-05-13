// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;

/**
 * @dev Settings for a buy order.
 */

library SettingsBitFlag {
    // default action is 0b00000000
    uint16 internal constant NONE = 0x00;

    // for if the price per item is set higher than the max price per item
    uint16 internal constant MAX_PRICE_PER_ITEM_EXCEEDED = 0x0001;
    // default: will skip the item.
    // if 0x01 is set, will by anyways without exceeding the max total spend allowance.

    // if the quantity of an item is less than the requested quantity (for ERC1155)
    uint16 internal constant INSUFFICIENT_QUANTITY_ERC1155 = 0x0002;
    // default: will skip the item.
    // if 0x02 is set, will buy as many items as possible (all listed items)

    // if marketplace fails to buy an item for some reason
    uint16 internal constant MARKETPLACE_BUY_ITEM_REVERTED = 0x0004;
    // default: will skip the item.
    // if 0x04 is set, will revert the buy transaction.

    // if total spend allowance is exceeded
    uint16 internal constant MAX_SPEND_ALLOWANCE_EXCEEDED = 0x0008;
    // default: will skip the item and continue.
    // if 0x08 is set, will skill the item and stop the transaction.

    // if every single item fails to buy
    uint16 internal constant EVERY_BUY_FAILURE = 0x0010;
    // default: will simply refund the buyer and return.
    // if 0x10 is set, will revert the transaction.

    // turn on success event logging
    uint16 internal constant EMIT_SUCCESS_EVENT_LOGS = 0x0020;
    // default: will not log success events.
    // if 0x20 is set, will log success events.

    // turn on failure event logging
    uint16 internal constant EMIT_FAILURE_EVENT_LOGS = 0x0040;
    // default: will not log failure events.
    // if 0x40 is set, will log failure events.

    uint16 internal constant MAX_BUYS_SUCCESSES = 0x0080;
    uint16 internal constant MAX_BUY_FAILURES = 0x0100;

    function checkSetting(uint16 _inputSettings, uint16 _settingBit)
        internal
        pure
        returns (bool)
    {
        return (_inputSettings & _settingBit) == _settingBit;
    }

    // function checkSettings(
    //     uint16 _inputSettings,
    //     uint16[] memory _settingBitArray
    // ) internal pure returns (bool) {
    //     uint16 sumSettingBits = 0;
    //     for (uint8 i = 0; i < _settingBitArray.length; i++) {
    //         sumSettingBits |= _settingBitArray[i];
    //     }
    //     return checkSetting(_inputSettings, sumSettingBits);
    // }
}
