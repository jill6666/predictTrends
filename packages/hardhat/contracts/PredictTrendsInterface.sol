// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

contract PredictTrendsStorage {
    uint256 upAmountSum; // 賭漲的總 shot 數
    uint256 downAmountSum; // 賭跌的總 shot 數
    uint256 public roundTime; // 每回合有多少開放時間

    uint256 public shotPrice; // 一注多少 eth
    uint256 public refundFee = 5; // 手續費 5 %
    
    uint256 public roundBlockNumber = 1; // 進行到第幾 round, 1 based

    bool public available = false; // 合約是鎖起來還是開著
    bool public inProgress = false; // 回合進行中

    address constant TST = 0x7af963cF6D228E564e2A0aA0DdBF06210B38615D;
    IERC20 public token = IERC20(TST);

    enum Trend {down, up, hold} // hold is a edge case

    struct OrderInfo {
        uint256 shot; // 多少注
        Trend trend; // 漲或跌 (0 跌 1 漲)
    }
    struct RoundInfo {
        uint256 startPrice; // 回合開始時的當前價格
        uint256 endPrice; // 回合結束時的當前價格
        Trend trendResult; // 漲或跌 (0 跌 1 漲)
    }
    
    /** roundId => user.address => {uint256 shot, bool trend} */
    mapping(uint256 => mapping(address => OrderInfo)) public roundOrderInfo;

    /** roundId => 回合開始時跟結束時的當前價格 */
    mapping(uint256 => RoundInfo) public roundPriceInfo;
}

abstract contract PredictTrendsInterface is PredictTrendsStorage {
    /*** PredictTrends Events ***/

    /**
     * @notice Event emitted when order is created
     */
    event CreateOrder(address orderer, uint256 shot, bool trend);

    /**
     * @notice Event emitted when order is updated
     */
    event UpdateOrder(address orderer, uint256 newShot, bool trend);

    /**
     * @notice Event emitted when order is refunded
     */
    event RefundOrder(address orderer, uint256 refundAmount, uint256 refundFee);

    /**
     * @notice Event emitted when order is claimed
     */
    event ClaimOrder(address orderer, uint256 bonusAmount, uint256 share, uint256 shotPrice, uint256 shot);

    

    /*** Admin Events ***/

    /**
     * @notice Event emitted when round is started
     */
    event RoundStarted(uint256 roundTime, uint256 roundBlockNumber, uint256 shotPrice, uint256 refundFee);

    /**
     * @notice Event emitted when order is end
     */
    event ExcuteResult(uint256 startPrice, uint256 endPrice, Trend trendResult);
    
    /**
     * @notice Event emitted when token in contract is withdraw by admin
     */
    event Withdraw(address to, uint256 withdrawAmount);

    /**
     * @notice Event emitted when the available is changed
     */
    event SetAvailable(address operator, bool isAvailable);

    /**
     * @notice Event emitted when the shotPrice is changed
     */
    event SetShotPrice(address operator, uint256 shotPrice);

    /**
     * @notice Event emitted when the roundTime is changed
     */
    event SetRoundTime(address operator, uint256 roundTime);

    /*** User Interface ***/
    function _getTrendResult(uint256 _startPrice, uint256 _endPrice) virtual internal returns (Trend);
    function _setRecordInfo(uint256 _shot, bool _trend) virtual internal ;
    function userClaim() virtual external returns(bool);
    function createOrder(uint256 _shot, bool _trend) virtual external;
    function _updateOrder(uint256 _shot, bool _trend) virtual internal;
    function refundOrder() virtual external;

    /*** Admin Functions ***/
    function startNewRound() virtual external;
    function excuteRoundResult() virtual external;
    function _resetState() virtual internal;
    function _getPrice() virtual internal returns(uint256);
    function setRoundTime(uint256 _seconds) virtual external;
    function setShotPrice(uint256 _price) virtual external;
    function setAvailable(bool _available) virtual external;
    function withdraw(uint256 _amount) virtual external;
}