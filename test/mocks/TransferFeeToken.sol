// SPDX-License-Identifier: GNU General Public License v3.0

pragma solidity 0.8.20;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from 'forge-std/console.sol';

contract TransferFeeToken is ERC20 {
    uint256 immutable fee;

    // --- Init ---
    constructor(uint256 _fee, string memory name, string memory symbol) ERC20(name, symbol) {
        fee = _fee;
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
    // --- Token ---

    function transferFrom(address src, address dst, uint256 amount) public override returns (bool) {
        require(balanceOf(src) >= amount, "insufficient-balance");
        if (src != msg.sender && allowance(src, msg.sender) != type(uint256).max) {
            console.log("allowance(src, msg.sender): ", allowance(src, msg.sender));
            console.log("amount: ", amount);
            require(allowance(src, msg.sender) >= amount, "insufficient-allowance");
            _approve(src, msg.sender, allowance(src, msg.sender) - amount);
        }

        _transfer(src, dst, amount - fee);
        _burn(src, fee);

        return true;
    }
}
