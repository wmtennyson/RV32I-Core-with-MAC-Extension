# Fixed Point Arithmetic Article Summaries

### Fixed-Point Arithmetic: An Introduction
- **Citation**: Fixed-Point Arithmetic: An Introduction — Randy Yates, Digital Signal Labs White Paper, 2013.
- **Description**:
    Fixed-point arithmetic refers to mathematical operations with a defined decimal point; in other words, the programmer chooses the precision of the system by defining where the decimal point is. Contrasting against a floating point system, where the precision can be modified, the fixed point arithmetic system chooses how many decimal places are needed and cannot change after that. Hence the name floating (decimal can move) vs. fixed (decimal stays put). Through binary, the formula is as follows:
                                    $$U(a,b) = 2^n/2^b$$
Where _a_ is the number of non-fractional bits, _b_ is the number of fractional bits, and _n_ is the number of total bits. Example:
$$Given 1000 0010 - U(6, 2) = 2 $$
    
