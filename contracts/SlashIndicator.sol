pragma solidity ^0.5.0;
import { System } from "./System.sol";

contract SlashIndicator is System{
    uint256 public constant tolerateDistance = 1000;
    uint256 public constant sprint = 100;
    uint256 public constant outTurnDif = 1;

    event NewValidatorSlash(address indexed validator);


    struct Indicator {
        uint256 height;
        uint256 count;
        bool exist;
    }

    mapping(address => Indicator) indicators;
    uint256 public previousHeight;

    modifier onlyOutTurnBlock() {
        require(block.difficulty == outTurnDif);
        _;
    }

    modifier onlyOnce() {
        require(block.number > previousHeight);
        _;
        previousHeight = block.number;
    }

    /**
     * @dev Increase the count of the according indicator.
     */
    function slash(address validator) external onlySystem onlyOnce onlyOutTurnBlock{
        Indicator memory indicator = indicators[validator];
        if (indicator.exist){
            if (block.number-indicator.height < tolerateDistance){
                indicator.count++;
                if (indicator.count % sprint == 0){
                    emit NewValidatorSlash(validator);
                }
            }
        }else{
            indicator.exist = true;
        }
        indicator.height=block.number;
        indicators[validator] = indicator;
    }

    function getSlashIndicator(address validator) view returns (uint256,uint256){
        Indicator memory indicator = indicators[validator];
        return (indicator.height, indicator.count);
    }
}