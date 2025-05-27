// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Script.sol";
import "../src/EtherSub.sol";

contract DeployEtherSub is Script {
    function run() external returns (EtherSub) {
        vm.startBroadcast();

        EtherSub etherSub = new EtherSub();

        vm.stopBroadcast();
        
        console.log("EtherSub deployed at:", address(etherSub));
        return etherSub;
    }
}
