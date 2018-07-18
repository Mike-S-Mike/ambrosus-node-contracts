/*
Copyright: Ambrosus Technologies GmbH
Email: tech@ambrosus.com

This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at https://mozilla.org/MPL/2.0/.

This Source Code Form is “Incompatible With Secondary Licenses”, as defined by the Mozilla Public License, v. 2.0.
*/

pragma solidity ^0.4.23;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../Lib/SafeMathExtensions.sol";
import "../Boilerplate/Head.sol";
import "../Configuration/Config.sol";
import "../Configuration/Time.sol";


contract Fees is Base, Ownable {

    using SafeMath for uint;
    using SafeMathExtensions for uint;

    uint constant public CHALLENGER_FEE_DIVIDER = 10;
    uint constant public CHALLENGER_FEE_MULTIPLIER = 7;
    uint constant public VALIDATOR_FEE_DIVIDER = 4;
    uint constant public UPLOAD_FEE_TO_CHALLENGE_FEE_RATIO = 10;

    uint public baseUploadFee = 10 ether;

    constructor(Head _head) public Base(_head) {
    }

    function setBaseUploadFee(uint fee) public onlyOwner {
        baseUploadFee = fee;
    }
    
    function getFeeForUpload(uint storagePeriods) public view returns(uint) {
        require(storagePeriods > 0);
        return baseUploadFee.mul(storagePeriods);
    }

    function getFeeForChallenge(uint storagePeriods) public view returns (uint) {
        return getFeeForUpload(storagePeriods).div(UPLOAD_FEE_TO_CHALLENGE_FEE_RATIO);
    }

    function calculateFeeSplit(uint value) public pure returns (uint challengeFee, uint validatorsFee, uint burnFee) {
        challengeFee = value.mul(CHALLENGER_FEE_MULTIPLIER).div(CHALLENGER_FEE_DIVIDER);
        validatorsFee = value.div(VALIDATOR_FEE_DIVIDER);
        burnFee = value.sub(validatorsFee).sub(challengeFee);
    }

    function getPenalty(uint nominalStake, uint penaltiesCount, uint lastPenaltyTime) public view returns(uint penalty, uint newPenaltiesCount) {
        Config config = context().config();
        Time time = context().time();
        if ((time.currentTimestamp() - lastPenaltyTime) > config.PENALTY_ESCALATION_TIMEOUT()) {
            return (nominalStake.div(config.PENALTY_DIVIDER()), 1);
        } else {
            return (nominalStake.div(config.PENALTY_DIVIDER()).mul(penaltiesCount.safePow2()), penaltiesCount + 1);
        }
    }
}
