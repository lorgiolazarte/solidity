// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract array {
    
    uint256[] public arr1;                      // array vacio
    uint256[] public arr2 = [22, 33, 44];       // array con elementos
    uint256[10] public arr3;                    // array no tiene elementos pero se cuantos voy a guardar

    // trae un elemento en particular del array
    function get(uint _i) public view returns (uint256) {
        return arr2[_i];
    }    

    // trae el array completo    
    function getArr() public view returns (uint256[] memory){
        return arr2;
    }

    // colocar un nuevo elemento en el array
    function push(uint256 _i) public {
        arr2.push(_i);
    }

    // borra el ultimo elemento en el array
    function pop() public  {
        arr2.pop();
    }

    // contar el numero de ele,entos que tiene el array
    function getLength() public view returns (uint256) {
        return arr2.length;
    }

    // borrar un elemento en particular de un array
    function remove(uint256 _index) public {
        delete arr2[_index];
    }

}
