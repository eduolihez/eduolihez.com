<?php
/**
 * Carga funciones concretas de un fuente PHP que no se puede incluir en la
 * suite (layout.php y auth.php arrancan sesion y BD, ver bootstrap.php): se
 * extrae el codigo de cada funcion con el tokenizer y se evalua aparte. Las
 * que ya existen no se vuelven a declarar.
 *
 * @param list<string> $names
 */
function extract_php_functions(string $file, array $names): void
{
    $pending = array_values(array_filter($names, static fn(string $n): bool => !function_exists($n)));
    if (!$pending) {
        return;
    }
    $tokens = token_get_all((string) file_get_contents($file));
    $n = count($tokens);
    for ($i = 0; $i < $n; $i++) {
        if (!is_array($tokens[$i]) || $tokens[$i][0] !== T_FUNCTION) {
            continue;
        }
        $j = $i + 1;
        while ($j < $n && is_array($tokens[$j]) && $tokens[$j][0] === T_WHITESPACE) {
            $j++;
        }
        if (!is_array($tokens[$j]) || !in_array($tokens[$j][1], $pending, true)) {
            continue;
        }
        $code = '';
        $depth = 0;
        $opened = false;
        for ($k = $i; $k < $n; $k++) {
            $t = $tokens[$k];
            $code .= is_array($t) ? $t[1] : $t;
            if ($t === '{' || (is_array($t) && in_array($t[0], [T_CURLY_OPEN, T_DOLLAR_OPEN_CURLY_BRACES], true))) {
                $depth++;
                $opened = true;
            } elseif ($t === '}') {
                $depth--;
                if ($opened && $depth === 0) {
                    break;
                }
            }
        }
        eval($code);
        $i = $k;
    }
}
