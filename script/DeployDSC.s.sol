// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    // HelperConfig public helperConfig;

    constructor() {}

    function run()
        external
        returns (
            /**
             * (Contract contract)
             */
            HelperConfig helperConfig
        )
    {
        helperConfig = new HelperConfig();

        vm.startBroadcast();
        // deploy your contract here...
        vm.stopBroadcast();
    }
}
