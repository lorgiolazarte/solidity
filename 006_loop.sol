// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract Loop {
    function loop() pure public {
        //for loop
        for (uint256 i=0; i < 10; i++){
            if (i == 3) {
                continue;
            }
            if (i == 5) {
                break;
            }
        }
    }   

   /*
    //while loop
    uint256 j = 0;
    uint256 segurity = 0;    

    while (j < 10){
        j++;
        if (segurity > 100) {
            break;
        }
        segurity ++;
    }

    */
}