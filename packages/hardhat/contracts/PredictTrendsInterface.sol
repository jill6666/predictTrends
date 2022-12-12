// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PredictTrendsStorage {

    /*** Counter Storage ***/

    // Map value to counter
    mapping(uint256 => uint256) public counterToValue;

    // Map the last updated time to the counter
    mapping(uint256 => uint256) public counterToLastTimeStamp;

    // Map counter to to the upkeep
    mapping(uint256 => uint256) public counterToUpKeepID;

    bytes performData;

    /*** Predict Trends Storage ***/

    uint256 upAmountSum; // 賭漲的總 shot 數
    uint256 downAmountSum; // 賭跌的總 shot 數

    // Set upkeep interval to 60 * 60 * 24 seconds (86400)
    // using 60 in dev
    uint256 interval = 60;

    uint256 public roundTime; // 每回合有多少開放時間
    uint256 public roundTimeLowerLimit = 300; // 每回合最少要幾秒

    uint256 public shotPrice; // 一注多少 eth
    uint256 public refundFee = 5; // 退款手續費 5 %
    uint256 public claimFee = 1; // 領獎手續費 1 %
    
    uint256 public roundBlockNumber = 0; // 進行到第幾 round, 0 based

    bool public inProgress = false; // 回合進行中

    enum Trend {down, up, hold} // hold is a edge case

    struct OrderInfo {
        uint256 shot; // 多少注
        Trend trend; // 漲或跌 (0 跌 1 漲)
    }
    struct RoundInfo {
        int startPrice; // 回合開始時的當前價格
        int endPrice; // 回合結束時的當前價格
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

    /**
     * @notice Event emitted when order is refunded in hold trend result
     */
    event RefundInHoldResult(address orderer, uint256 refundAmount);

    /**
     * @notice Event emitted when received value
     */
    event Received(address, uint256);

    

    /*** Admin Events ***/

    /**
     * @notice Event emitted when round is started
     */
    event RoundStarted(uint256 roundTime, uint256 roundBlockNumber, uint256 shotPrice, uint256 refundFee);

    /**
     * @notice Event emitted when order is end
     */
    event ExcuteResult(int startPrice, int endPrice, Trend trendResult);
    
    /**
     * @notice Event emitted when token in contract is withdraw by admin
     */
    event Withdraw(address to, uint256 withdrawAmount);

    /**
     * @notice Event emitted when the shotPrice is changed
     */
    event SetShotPrice(address operator, uint256 shotPrice);

    /**
     * @notice Event emitted when the roundTime is changed
     */
    event SetRoundTime(address operator, uint256 roundTime);

    AggregatorV3Interface internal priceFeed;
        
    /**
     * Network: Goerli
     * Aggregator: ETH/USD
     * Address: 0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
     */
    constructor() {
        priceFeed = AggregatorV3Interface(
            0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e
        );
    }

    /*** User Interface ***/
    function userClaim(uint256 _roundBlockNumber) virtual external returns(bool);
    function createOrder(uint256 _shot, bool _trend) virtual external payable;
    function updateOrder(uint256 _shot, bool _trend) virtual external payable;
    function refundOrder() virtual external;
    function _getTrendResult(int _startPrice, int _endPrice) virtual internal returns (Trend);
    function _setRecordInfo(uint256 _shot, bool _trend) virtual internal ;

    /*** Admin Functions ***/
    function startNewRound() virtual external;
    function excuteRoundResult() virtual external;
    function setRoundTime(uint256 _seconds) virtual external;
    function setShotPrice(uint256 _price) virtual external;
    function withdraw(uint256 _amount) virtual external;
    function _resetState() virtual internal;


    /*** Utils ***/
    function _isContract(address addr) view internal returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function _safeTransferETH(address _to, uint256 _value) internal {
        (bool success, ) = _to.call{value: _value}(new bytes(0));
        require(success, "Failed to send Ether");
    }

    /**
     * Returns the latest price
     */
    function _getPrice() view internal returns (int) {
        (
            ,
            /*uint80 roundID*/ int price /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/,
            ,
            ,

        ) = priceFeed.latestRoundData();
        return price;
    }

    modifier nonContractCall(address addr) {
        require(!_isContract(addr), "ERROR: Only EOA can enteract with.");
        _;
    }

    modifier onlyInProgress() {
        require(inProgress, "ERROR: Need to in progress.");
        _;
    }

    modifier notInProgress() {
        require(!inProgress, "ERROR: Not available when in progress.");
        _;
    }
}