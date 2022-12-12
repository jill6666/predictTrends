// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Counters.sol";
import {AutomationRegistryInterface, State, Config} from "@chainlink/contracts/src/v0.8/interfaces/AutomationRegistryInterface1_2.sol";
import {LinkTokenInterface} from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

interface KeeperRegistrarInterface {
    function register(
        string memory name,
        bytes calldata encryptedEmail,
        address upkeepContract,
        uint32 gasLimit,
        address adminAddress,
        bytes calldata checkData,
        uint96 amount,
        uint8 source,
        address sender
    ) external;
}

contract SelfAutomatingCounter {
    // Set up the counter
    using Counters for Counters.Counter;

    // Store the counter id
    Counters.Counter private _counterIdCounter;

    // Map value to counter
    mapping(uint256 => uint256) public counterToValue;

    // Map the last updated time to the counter
    mapping(uint256 => uint256) public counterToLastTimeStamp;

    // Map counter to to the upkeep
    mapping(uint256 => uint256) public counterToUpKeepID;

    // Set upkeep interval to 60 seconds
    uint256 interval = 60;

    // Setup keeper registry infomation
    LinkTokenInterface public immutable i_link;
    address public immutable registrar;
    AutomationRegistryInterface public immutable i_registry;
    bytes4 registerSig = KeeperRegistrarInterface.register.selector;

    // pass the token and the registry info
    constructor(
        LinkTokenInterface _link,
        address _registrar,
        AutomationRegistryInterface _registry
    ) {
        // 0x326C977E6efc84E512bB9C30f76E30c160eD06FB -- Goerli
        i_link = _link;
        // 0x9806cf6fBc89aBF286e8140C42174B94836e36F2 -- Goerli
        registrar = _registrar;
        // 0x02777053d6764996e594c3E88AF1D58D5363a2e6 -- Goerli
        i_registry = _registry;
    }

    // Create a new counter
    function createNewCounter() public returns (uint256) {
        uint256 counterID = _counterIdCounter.current();

        _counterIdCounter.increment();
        counterToValue[counterID] = 0;
        counterToLastTimeStamp[counterID] = block.timestamp;
        
        return counterID;
    }
}