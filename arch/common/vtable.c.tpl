// $cls $table_type

typedef $c_type ${name}_type;

// A lot of nonsense to avoid warnings from both gcc and g++
#ifdef __cplusplus
extern
#else
extern const __attribute__((weak))
${name}_type $name$brackets;
#endif  // __cplusplus
const __attribute__((weak))
${name}_type $name$brackets = { $vals }; 

