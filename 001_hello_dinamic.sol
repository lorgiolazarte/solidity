// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

contract hello_dinamic {
    string saludo_d = "Saludo Dinamico";
    string public saludo_e = "Saludo inicial despliegue contrato - estatico";

    function leerSaludo () public view returns (string memory ) {
        return saludo_d;
    }

    function guardarSaludo(string memory _nuevoSaludo) public  {
        saludo_d = _nuevoSaludo; 
    }
}