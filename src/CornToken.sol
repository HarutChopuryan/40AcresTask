// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {CornMinted, CornBurned} from "./helpers/Events.sol";

contract CornToken is ERC20, Ownable {
    constructor(address initialOwner) ERC20("Corn Token", "CORN") Ownable(initialOwner) {}

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit CornMinted(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
        emit CornBurned(from, amount);
    }
}
