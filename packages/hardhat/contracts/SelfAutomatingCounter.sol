// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/utils/Counters.sol";
import { AutomationRegistryInterface, State, Config } from "@chainlink/contracts/src/v0.8/interfaces/AutomationRegistryInterface1_2.sol";
import { LinkTokenInterface } from "@chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol";

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

    // Pass the token and the registry info
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

    function registerAndPredictID(
        string memory name,
        uint32 gasLimit,
        uint96 amount
    ) public {
        // Create a new counter
        uint256 counterID = createNewCounter();
        (State memory state, Config memory _c, address[] memory _k) = i_registry
            .getState();
        uint256 oldNonce = state.nonce;
        // Pass into counter ID as check data
        bytes memory checkData = abi.encodePacked(counterID);
        // Encode the data to send registrar
        bytes memory payload = abi.encode(
            name,
            '0x',
            address(this),
            // 999999
            gasLimit,
            address(msg.sender),
            checkData,
            // 5000000000000000000
            amount,
            0,
            address(this)
        );
        // transfer LINK token to registrar
        i_link.transferAndCall(registrar, amount, bytes.concat(registerSig, payload));
        (state, _c, _k) = i_registry.getState();

        uint256 newNonce = state.nonce;
        if(newNonce == oldNonce + 1) {
            uint256 upkeepID = uint256(keccak256(
                abi.encodePacked(
                    blockhash(block.number - 1),
                    address(i_registry),
                    uint256(oldNonce)
                )
            ));
            // Set the upkeep id for the counter id
            counterToUpKeepID[counterID] = upkeepID;
        } else {
            revert('auto-approve disabled');
        }
    }

    // checkUpkeep expects the counter id as the check data this will run for each new counter
    function checkUpkeep(bytes calldata checkData) external view returns (bool upkeepNeeded, bytes memory performData) {
        // Decode the check data
        uint256 counterID = abi.decode(checkData, (uint256));
        // If the interval has passed then return true
        upkeepNeeded = (block.timestamp - counterToLastTimeStamp[counterID]) > interval;
        // Pass checkData through
        performData = checkData;
    }

    function performUpkeep(bytes calldata performData) external {
        // Decode the check data
        uint256 counterID = abi.decode(performData, (uint256));

        // revalidating the upkeep in the performUpkeep function
        if ((block.timestamp - counterToLastTimeStamp[counterID]) > interval) {
            // Update the last update time
            counterToLastTimeStamp[counterID] = block.timestamp;
            // Increment the value
            counterToValue[counterID] = counterToValue[counterID] + 1;
        }
    }
}