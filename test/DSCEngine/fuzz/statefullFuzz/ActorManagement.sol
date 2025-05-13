// SPDX-License-Identifier: MIT

pragma solidity 0.8.25;

/*
 * @title ActorManagement
 * @author 0XC4RL0S
 * @notice This contract containing the actor configuration.
 */

contract ActorManagement {
  // Actors are the addresses to be used as senders.
  address internal constant ACTOR_1 = address(0x10000);
  address internal constant ACTOR_2 = address(0x20000);
  address internal constant ACTOR_3 = address(0x30000);
  address internal constant ACTOR_4 = address(0x40000);

  // List of all actors
  address[] internal actors = [ACTOR_1, ACTOR_2, ACTOR_3, ACTOR_4];

  // Variable containing the current actor.
  address internal currentActor;

  // Debug toggle to disable setting the current actor.
  bool internal debugModeActor = true;

  // Starting balance for all actors
  uint256 internal constant STARTING_BALANCE = 1_000_000_000_000 ether;

  /// @notice Modifier storing `msg.sender` for the duration of the function call.
  modifier setCurrentActor(uint256 actorIndexSeed) {
    address previousActor = currentActor;
    if (debugModeActor) {
      currentActor = msg.sender;
    }
    _;
    if (debugModeActor) {
      currentActor = previousActor;
    }
  }
}
