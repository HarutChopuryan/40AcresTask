// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {CornToken} from "../src/CornToken.sol";
import {CornDex} from "../src/CornDex.sol";
import {Lending} from "../src/Lending.sol";
import {MovePrice} from "../src/MovePrice.sol";
import {FlashLoanLiquidator} from "../src/FlashLoanLiquidator.sol";

/// @notice Deploy all contracts to a local Anvil node.
///         Usage: forge script script/Deploy.s.sol --rpc-url http://127.0.0.1:8545 --broadcast
contract DeployScript is Script {
    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        uint256 initialEthPrice = 2000e18; // 1 ETH = 2000 CORN

        CornToken cornToken = new CornToken(deployer);
        console.log("CornToken:", address(cornToken));

        CornDex cornDex = new CornDex(initialEthPrice, deployer);
        console.log("CornDex:", address(cornDex));

        Lending lending = new Lending(address(cornToken), address(cornDex), deployer);
        console.log("Lending:", address(lending));

        MovePrice movePrice = new MovePrice(address(cornDex), deployer);
        console.log("MovePrice:", address(movePrice));

        FlashLoanLiquidator liquidator = new FlashLoanLiquidator(address(lending), address(cornToken));
        console.log("FlashLoanLiquidator:", address(liquidator));

        // Transfer ownership: CornDex -> MovePrice (so MovePrice can change prices)
        cornDex.transferOwnership(address(movePrice));

        // Transfer ownership: CornToken -> Lending (so Lending can mint/burn)
        cornToken.transferOwnership(address(lending));

        vm.stopBroadcast();

        console.log("\n--- Deployment Complete ---");
        console.log("Deployer:", deployer);
    }
}
