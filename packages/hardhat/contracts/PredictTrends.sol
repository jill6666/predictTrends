// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

// token = GoerliETH
contract PredictTrends is Ownable {
    uint256 upAmountSum; // 賭漲的總 shot 數
    uint256 downAmountSum; // 賭跌的總 shot 數
    uint256 roundTime; // 每回合有多少開放時間

    uint256 shotPrice; // 一注多少 eth
    uint256 shotLimit; // 最多下幾注（最少就是 1 ，要提高就提高 shotPrice 就好）
    
    uint256 roundBlockNumber = 1; // 進行到第幾 round, 1 based

    bool public available = false; // 合約是鎖起來還是開著
    bool public claimable = !available; // user 是否可以拿錢

    address public constant TST = 0x7af963cF6D228E564e2A0aA0DdBF06210B38615D;


    enum Trend {down, up}
    Trend trend;

    struct Info {
        uint256 shot; // 多少注
        bool trend; // 漲或跌 (0 跌 1 漲)
    }
    
    /** roundId => user.address => {uint256 shot, bool trend} */
    mapping(uint256 => mapping(address => Info)) public roundOrderInfo;

    /** roundId => 回合開始時的當前價格 */
    mapping(uint256 => uint256) public roundPrice;


    /** 開啟新的一回合 */
    function startNewRound() onlyOwner public {
        setAvailable(true);
        _getPrice();
        _countdown();
    }

    function _countdown() private {
        // TODO: how to countdown on block chain?
        _resetState();
    }

    function _resetState() private {}

    /** 跟 chainlink 拿資訊 */
    function _getPrice() private {
        uint256 mockPrice = 4000;
        roundPrice[roundBlockNumber] = mockPrice;
    }

    /** 調整每回合的時長，是過了幾秒不是切確的時間 */
    function setRoundTime(uint256 _seconds) onlyOwner public {
        require(_seconds >= 300, "ERROR: Round time should be grater than or equal to 300 seconds.");
        roundTime = _seconds;
    }

    /** 設定一注多少錢 */
    function setShotPrice(uint256 _price) onlyOwner public {
        require(_price > 0, "ERROR: Price must be greater than 0.");
        shotPrice = _price;
    }

    /** 設定最多能下幾注 */
    function setShotLimit(uint256 _limit) onlyOwner public {
        require(_limit > 0, "ERROR: Limit must be greater than 0.");
        shotLimit = _limit;
    }

    /** for emergency close */
    function setAvailable(bool _available) onlyOwner public {
        available = _available;
    }

    /** 紀錄這筆交易的內容，誰、賭多少、賭什麼 */
    function _recordInfo(uint256 _shot, bool _trend) private {
        roundOrderInfo[roundBlockNumber][msg.sender].shot = _shot;
        roundOrderInfo[roundBlockNumber][msg.sender].trend = _trend;

        if(_trend) upAmountSum + _shot;
        else downAmountSum + _shot;
    }

    /** 贏家來兌獎計算他的 share 、可以拿多少錢，輸家直接 revert */
    function userClaim() public nonContractCall(msg.sender) {
        require(claimable, "ERROR: Cannot claim currently.");
    }

    /** user 建立一筆賭注 */
    function createOrder(uint256 _shot, bool _trend) public nonContractCall(msg.sender) onlyAvailable {
        require(roundOrderInfo[roundBlockNumber][msg.sender].shot == 0, "ERROR: You've already one, use update instead.");
        require(IERC20(TST).balanceOf(msg.sender) >= _shot * shotPrice, "ERROR: your TST is not enough");

        _recordInfo(_shot, _trend);
    }

    /** user 更新賭注 */
    function updateOrder(uint256 _shot, bool _trend) public nonContractCall(msg.sender) onlyAvailable {
        uint256 originalShot = roundOrderInfo[roundBlockNumber][msg.sender].shot;

        require(originalShot >= 0, "ERROR: No order created yet.");
        require(IERC20(TST).balanceOf(msg.sender) >= _shot * shotPrice, "ERROR: Your TST is not enough.");
        require(_shot >= originalShot, "ERROR: New shot should be greater than original shot.");

        _recordInfo(_shot, _trend);
    }

    /** user 不想玩了 */
    function refundOrder() public nonContractCall(msg.sender) onlyAvailable {
        // TODO: require something
        delete roundOrderInfo[roundBlockNumber][msg.sender];
    }

    function withdraw() onlyOwner public {}

    function isContract(address addr) public returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    modifier nonContractCall(address addr) {
        require(!isContract(addr), "ERROR: Only EOA can enteract with.");
        _;
    }

    modifier onlyAvailable() {
        require(available, "ERROR: Not available.");
        _;
    }

    receive() external payable {}
}