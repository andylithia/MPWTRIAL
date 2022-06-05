# Unnamed Trial Project

- [x] HP35 CPU Board Replica, from rjw's patently-obvious
- [ ] Inverter Chain Comparator
- [ ] 64-bit Inverter Chain TDC
- [x] OPAMP
- [ ] RF Oscillator & Radiation Antenna

## Usage Notes

- To run simulation locally, in ./caravel/ run 
``` 
cd ./caravel/ 
make install_mcw
ln -s ./mgmt_core_wrapper ../mgmt_core_wrapper
```
- The symbol link should be removed before committing to GitHub
