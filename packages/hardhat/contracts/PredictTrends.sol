// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

contract predictTrends is Ownable {
    uint256 upAmountSum; // 多少人賭漲
    uint256 downAmountSum;

    bool public available = false;

    mapping(address => Info) public records;
    mapping(address => uint256) public rounds; // share

    enum Trend {up, down}
    Trend trend;

    struct Info {
        uint256 amount; // 
        bool trend; //
    }

    /** 開啟新的一回合 */
    function startNewRound() onlyOwner public {
        // TODO: 
        available = true;
    }

    /** 調整結束時間，是過了幾秒不是切確的時間 */
    function setEndTime() onlyOwner public {}

    /** 設定一注多少錢 */
    function setBasicPrice() onlyOwner public {}

    /** 設定最多能下幾注 */
    function setPriceLimit() onlyOwner public {}

    /** emergency close */
    function _switchAvailable() onlyOwner public {
        available = !available;
    }

    /**  */
    function _recordInfo() private {}
}