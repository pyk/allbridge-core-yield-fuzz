// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { Test } from "./Test.sol";

contract ContextProvider is Test {
    //============================================================//
    //                           Users                            //
    //============================================================//

    address public admin = makeAddr("admin");

    address[3] users;
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public carol = makeAddr("carol");

    function addUsers() internal {
        users[0] = alice;
        users[1] = bob;
        users[2] = carol;
    }

    function getRandomUser(uint256 userId)
        external
        view
        returns (address user)
    {
        userId = bound(userId, 0, users.length - 1);
        user = users[userId];
    }
}
