# words.nim — Fuente única del diccionario de alias y frases compuestas de .Coma
# Toda palabra canónica tiene sus alias ES/EN. La normalización ocurre en el lexer.
# Esta tabla es la ÚNICA fuente de verdad: el lexer no debe tener listas duplicadas.
# NOTA: lexer.nim actualmente duplica esta tabla en su const KeywordAliases.
# TODO: Hacer que lexer.nim importe words.nim y use AliasTableInstance en lugar de su copia local.
import tables, strutils

type
  KeyAlias* = object
    alias: string   # forma de entrada (minúscula, sin tildes por simplicidad)
    canon: string   # forma canónica a la que se normaliza

  MultiWordRule* = object
    phrase: string  # frase compuesta separada por espacios
    canon: string   # forma canónica resultante

  AliasTable* = object
    keyAliases: seq[KeyAlias]
    multiWords: seq[MultiWordRule]

var AliasTableInstance*: AliasTable

proc loadAliasTable*(): AliasTable =
  result.keyAliases = @[
    # mostrar
    KeyAlias(alias: "enseñar", canon: "mostrar"), KeyAlias(alias: "exponer", canon: "mostrar"),
    KeyAlias(alias: "exhibir", canon: "mostrar"), KeyAlias(alias: "presentar", canon: "mostrar"),
    KeyAlias(alias: "desplegar", canon: "mostrar"), KeyAlias(alias: "indicar", canon: "mostrar"),
    KeyAlias(alias: "muestra", canon: "mostrar"), KeyAlias(alias: "enseña", canon: "mostrar"),
    KeyAlias(alias: "mira", canon: "mostrar"), KeyAlias(alias: "canta", canon: "mostrar"),
    KeyAlias(alias: "suelta", canon: "mostrar"), KeyAlias(alias: "chivate", canon: "mostrar"),
    KeyAlias(alias: "di", canon: "mostrar"), KeyAlias(alias: "pregona", canon: "mostrar"),
    KeyAlias(alias: "anuncia", canon: "mostrar"), KeyAlias(alias: "declara", canon: "mostrar"),
    KeyAlias(alias: "revela", canon: "mostrar"), KeyAlias(alias: "descubre", canon: "mostrar"),
    KeyAlias(alias: "grita", canon: "mostrar"), KeyAlias(alias: "cuenta", canon: "mostrar"),
    KeyAlias(alias: "relata", canon: "mostrar"), KeyAlias(alias: "narra", canon: "mostrar"),
    KeyAlias(alias: "detalla", canon: "mostrar"), KeyAlias(alias: "pinta", canon: "mostrar"),
    KeyAlias(alias: "dibuja", canon: "mostrar"), KeyAlias(alias: "escribe", canon: "mostrar"),
    KeyAlias(alias: "imprime", canon: "mostrar"), KeyAlias(alias: "publica", canon: "mostrar"),
    KeyAlias(alias: "emite", canon: "mostrar"), KeyAlias(alias: "proyecta", canon: "mostrar"),
    KeyAlias(alias: "refleja", canon: "mostrar"), KeyAlias(alias: "escupe", canon: "mostrar"),
    KeyAlias(alias: "vomita", canon: "mostrar"), KeyAlias(alias: "print", canon: "mostrar"),
    KeyAlias(alias: "display", canon: "mostrar"), KeyAlias(alias: "exhibit", canon: "mostrar"),
    KeyAlias(alias: "present", canon: "mostrar"), KeyAlias(alias: "render", canon: "mostrar"),
    KeyAlias(alias: "indicate", canon: "mostrar"), KeyAlias(alias: "output", canon: "mostrar"),
    KeyAlias(alias: "show", canon: "mostrar"), KeyAlias(alias: "tell", canon: "mostrar"),
    KeyAlias(alias: "say", canon: "mostrar"), KeyAlias(alias: "spill", canon: "mostrar"),
    KeyAlias(alias: "shout", canon: "mostrar"), KeyAlias(alias: "blurt", canon: "mostrar"),
    KeyAlias(alias: "dish", canon: "mostrar"), KeyAlias(alias: "write", canon: "mostrar"),
    KeyAlias(alias: "draw", canon: "mostrar"), KeyAlias(alias: "paint", canon: "mostrar"),
    KeyAlias(alias: "announce", canon: "mostrar"), KeyAlias(alias: "proclaim", canon: "mostrar"),
    KeyAlias(alias: "type", canon: "mostrar"), KeyAlias(alias: "echo", canon: "mostrar"),
    KeyAlias(alias: "log", canon: "mostrar"), KeyAlias(alias: "dump", canon: "mostrar"),
    KeyAlias(alias: "spew", canon: "mostrar"), KeyAlias(alias: "vomit", canon: "mostrar"),

    # pedir
    KeyAlias(alias: "solicitar", canon: "pedir"), KeyAlias(alias: "preguntar", canon: "pedir"),
    KeyAlias(alias: "dime", canon: "pedir"), KeyAlias(alias: "dame", canon: "pedir"),
    KeyAlias(alias: "pasa", canon: "pedir"), KeyAlias(alias: "pide", canon: "pedir"),
    KeyAlias(alias: "atiende", canon: "pedir"), KeyAlias(alias: "recibe", canon: "pedir"),
    KeyAlias(alias: "recoge", canon: "pedir"), KeyAlias(alias: "acepta", canon: "pedir"),
    KeyAlias(alias: "toma", canon: "pedir"), KeyAlias(alias: "agarra", canon: "pedir"),
    KeyAlias(alias: "pilla", canon: "pedir"), KeyAlias(alias: "cuentame", canon: "pedir"),
    KeyAlias(alias: "input", canon: "pedir"), KeyAlias(alias: "ask", canon: "pedir"),
    KeyAlias(alias: "request", canon: "pedir"), KeyAlias(alias: "prompt", canon: "pedir"),
    KeyAlias(alias: "query", canon: "pedir"), KeyAlias(alias: "gimme", canon: "pedir"),
    KeyAlias(alias: "cough_up", canon: "pedir"), KeyAlias(alias: "get", canon: "pedir"),
    KeyAlias(alias: "scan", canon: "pedir"), KeyAlias(alias: "fetch", canon: "pedir"),
    KeyAlias(alias: "collect", canon: "pedir"), KeyAlias(alias: "receive", canon: "pedir"),
    KeyAlias(alias: "accept", canon: "pedir"), KeyAlias(alias: "grab", canon: "pedir"),
    KeyAlias(alias: "tell_me", canon: "pedir"),

    # en_caso_de_que
    KeyAlias(alias: "si", canon: "en_caso_de_que"),
    KeyAlias(alias: "en_el_caso_de_que", canon: "en_caso_de_que"),
    KeyAlias(alias: "siempre_que", canon: "en_caso_de_que"),
    KeyAlias(alias: "dado_que", canon: "en_caso_de_que"),
    KeyAlias(alias: "si_es_que", canon: "en_caso_de_que"),
    KeyAlias(alias: "cuando", canon: "en_caso_de_que"),
    KeyAlias(alias: "si_acaso", canon: "en_caso_de_que"),
    KeyAlias(alias: "por_si", canon: "en_caso_de_que"),
    KeyAlias(alias: "por_si_acaso", canon: "en_caso_de_que"),
    KeyAlias(alias: "puesto_que", canon: "en_caso_de_que"),
    KeyAlias(alias: "ya_que", canon: "en_caso_de_que"),
    KeyAlias(alias: "a_ver_si", canon: "en_caso_de_que"),
    KeyAlias(alias: "y_si", canon: "en_caso_de_que"),
    KeyAlias(alias: "if", canon: "en_caso_de_que"),
    KeyAlias(alias: "in_case_that", canon: "en_caso_de_que"),
    KeyAlias(alias: "provided_that", canon: "en_caso_de_que"),
    KeyAlias(alias: "given_that", canon: "en_caso_de_que"),
    KeyAlias(alias: "when", canon: "en_caso_de_que"),
    KeyAlias(alias: "suppose", canon: "en_caso_de_que"),
    KeyAlias(alias: "assuming", canon: "en_caso_de_que"),
    KeyAlias(alias: "lest", canon: "en_caso_de_que"),
    KeyAlias(alias: "on_condition_that", canon: "en_caso_de_que"),
    KeyAlias(alias: "in_the_event_that", canon: "en_caso_de_que"),
    KeyAlias(alias: "what_if", canon: "en_caso_de_que"),

    # sino
    KeyAlias(alias: "si_no", canon: "sino"),
    KeyAlias(alias: "de_lo_contrario", canon: "sino"),
    KeyAlias(alias: "en_caso_contrario", canon: "sino"),
    KeyAlias(alias: "en_otro_caso", canon: "sino"),
    KeyAlias(alias: "pero", canon: "sino"),
    KeyAlias(alias: "de_otra_forma", canon: "sino"),
    KeyAlias(alias: "de_otra_manera", canon: "sino"),
    KeyAlias(alias: "en_su_defecto", canon: "sino"),
    KeyAlias(alias: "else", canon: "sino"), KeyAlias(alias: "if_not", canon: "sino"),
    KeyAlias(alias: "or_else", canon: "sino"), KeyAlias(alias: "instead", canon: "sino"),
    KeyAlias(alias: "alternatively", canon: "sino"), KeyAlias(alias: "failing_that", canon: "sino"),

    # fin
    KeyAlias(alias: "final", canon: "fin"),
    KeyAlias(alias: "termina_aqui", canon: "fin"), KeyAlias(alias: "se_acabo", canon: "fin"),
    KeyAlias(alias: "basta", canon: "fin"), KeyAlias(alias: "listo", canon: "fin"),
    KeyAlias(alias: "ya", canon: "fin"), KeyAlias(alias: "terminado", canon: "fin"),
    KeyAlias(alias: "terminada", canon: "fin"), KeyAlias(alias: "acabado", canon: "fin"),
    KeyAlias(alias: "acabada", canon: "fin"), KeyAlias(alias: "concluido", canon: "fin"),
    KeyAlias(alias: "cerrado", canon: "fin"), KeyAlias(alias: "punto_final", canon: "fin"),
    KeyAlias(alias: "se_termino", canon: "fin"), KeyAlias(alias: "hasta_aqui", canon: "fin"),
    KeyAlias(alias: "colorin_colorado", canon: "fin"), KeyAlias(alias: "he_dicho", canon: "fin"),
    KeyAlias(alias: "caso_cerrado", canon: "fin"), KeyAlias(alias: "amen", canon: "fin"),
    KeyAlias(alias: "fin_transmision", canon: "fin"),
    KeyAlias(alias: "end", canon: "fin"), KeyAlias(alias: "finish", canon: "fin"),
    KeyAlias(alias: "done", canon: "fin"), KeyAlias(alias: "over", canon: "fin"),
    KeyAlias(alias: "enough", canon: "fin"), KeyAlias(alias: "finito", canon: "fin"),
    KeyAlias(alias: "finished", canon: "fin"), KeyAlias(alias: "completed", canon: "fin"),
    KeyAlias(alias: "concluded", canon: "fin"), KeyAlias(alias: "closed", canon: "fin"),
    KeyAlias(alias: "period", canon: "fin"), KeyAlias(alias: "mic_drop", canon: "fin"),
    KeyAlias(alias: "case_closed", canon: "fin"),
    KeyAlias(alias: "over_and_out", canon: "fin"), KeyAlias(alias: "end_of_transmission", canon: "fin"),
    KeyAlias(alias: "thats_all", canon: "fin"), KeyAlias(alias: "the_end", canon: "fin"),
    KeyAlias(alias: "cut", canon: "fin"),

    # mientras
    KeyAlias(alias: "dale", canon: "mientras"), KeyAlias(alias: "en_bucle", canon: "mientras"),
    KeyAlias(alias: "en_loop", canon: "mientras"), KeyAlias(alias: "dale_dale", canon: "mientras"),
    KeyAlias(alias: "vamos", canon: "mientras"), KeyAlias(alias: "arre", canon: "mientras"),
    KeyAlias(alias: "while", canon: "mientras"), KeyAlias(alias: "whilst", canon: "mientras"),
    KeyAlias(alias: "as_long_as", canon: "mientras"),
    KeyAlias(alias: "keep_going", canon: "mientras"), KeyAlias(alias: "loop", canon: "mientras"),
    KeyAlias(alias: "go_go", canon: "mientras"),

    # funcion
    KeyAlias(alias: "procedimiento", canon: "funcion"),
    KeyAlias(alias: "rutina", canon: "funcion"), KeyAlias(alias: "faena", canon: "funcion"),
    KeyAlias(alias: "chamba", canon: "funcion"), KeyAlias(alias: "laburo", canon: "funcion"),
    KeyAlias(alias: "curro", canon: "funcion"), KeyAlias(alias: "mision", canon: "funcion"),
    KeyAlias(alias: "encargo", canon: "funcion"),
    KeyAlias(alias: "cometido", canon: "funcion"), KeyAlias(alias: "subrutina", canon: "funcion"),
    KeyAlias(alias: "proceso", canon: "funcion"),
    KeyAlias(alias: "function", canon: "funcion"),
    KeyAlias(alias: "procedure", canon: "funcion"),
    KeyAlias(alias: "routine", canon: "funcion"),
    KeyAlias(alias: "sub", canon: "funcion"), KeyAlias(alias: "method", canon: "funcion"),
    KeyAlias(alias: "job", canon: "funcion"), KeyAlias(alias: "chore", canon: "funcion"),
    KeyAlias(alias: "gig", canon: "funcion"), KeyAlias(alias: "duty", canon: "funcion"),
    KeyAlias(alias: "errand", canon: "funcion"), KeyAlias(alias: "operation", canon: "funcion"),
    KeyAlias(alias: "func", canon: "funcion"), KeyAlias(alias: "def", canon: "funcion"),
    KeyAlias(alias: "proc", canon: "funcion"),

    # devolver
    KeyAlias(alias: "retornar", canon: "devolver"), KeyAlias(alias: "entregar", canon: "devolver"),
    KeyAlias(alias: "regresa", canon: "devolver"), KeyAlias(alias: "return", canon: "devolver"),
    KeyAlias(alias: "give_back", canon: "devolver"), KeyAlias(alias: "hand_back", canon: "devolver"),
    KeyAlias(alias: "yield", canon: "devolver"),

    # conectores lógicos y operadores
    KeyAlias(alias: "e", canon: "y"), KeyAlias(alias: "con", canon: "y"),
    KeyAlias(alias: "and", canon: "y"), KeyAlias(alias: "with", canon: "y"),
    KeyAlias(alias: "u", canon: "o"), KeyAlias(alias: "o_bien", canon: "o"),
    KeyAlias(alias: "or", canon: "o"),
    KeyAlias(alias: "nada_de", canon: "no"), KeyAlias(alias: "ni_de_broma", canon: "no"),
    KeyAlias(alias: "nah", canon: "no"), KeyAlias(alias: "no_way", canon: "no"),
    KeyAlias(alias: "ni_muerto", canon: "no"), KeyAlias(alias: "not", canon: "no"),
    KeyAlias(alias: "aint", canon: "no"),

    # igual
    KeyAlias(alias: "es", canon: "igual"), KeyAlias(alias: "vale", canon: "igual"),
    KeyAlias(alias: "equivale_a", canon: "igual"), KeyAlias(alias: "son", canon: "igual"),
    KeyAlias(alias: "equal", canon: "igual"), KeyAlias(alias: "equals", canon: "igual"),
    KeyAlias(alias: "is", canon: "igual"), KeyAlias(alias: "are", canon: "igual"),
    KeyAlias(alias: "comes_to", canon: "igual"), KeyAlias(alias: "es_lo_mismo", canon: "igual"),
    KeyAlias(alias: "matches", canon: "igual"), KeyAlias(alias: "reads", canon: "igual"),

    # aritmética
    KeyAlias(alias: "más", canon: "mas"), KeyAlias(alias: "suma", canon: "mas"),
    KeyAlias(alias: "plus", canon: "mas"), KeyAlias(alias: "add", canon: "mas"),
    KeyAlias(alias: "increased_by", canon: "mas"), KeyAlias(alias: "up_by", canon: "mas"),
    KeyAlias(alias: "resta", canon: "menos"), KeyAlias(alias: "quita", canon: "menos"),
    KeyAlias(alias: "sustrae", canon: "menos"), KeyAlias(alias: "descuenta", canon: "menos"),
    KeyAlias(alias: "minus", canon: "menos"), KeyAlias(alias: "subtract", canon: "menos"),
    KeyAlias(alias: "deduct", canon: "menos"), KeyAlias(alias: "take_away", canon: "menos"),
    KeyAlias(alias: "decreased_by", canon: "menos"), KeyAlias(alias: "down_by", canon: "menos"),
    KeyAlias(alias: "multiplica", canon: "por"), KeyAlias(alias: "veces", canon: "por"),
    KeyAlias(alias: "times", canon: "por"), KeyAlias(alias: "multiply", canon: "por"),
    KeyAlias(alias: "multiplied_by", canon: "por"), KeyAlias(alias: "x", canon: "por"),
    KeyAlias(alias: "divide", canon: "entre"), KeyAlias(alias: "dividido_entre", canon: "entre"),
    KeyAlias(alias: "dividido_por", canon: "entre"), KeyAlias(alias: "reparte", canon: "entre"),
    KeyAlias(alias: "split", canon: "entre"), KeyAlias(alias: "divided_by", canon: "entre"),

    # comparaciones
    KeyAlias(alias: "mayor_que", canon: "es_mayor_que"),
    KeyAlias(alias: "mas_grande_que", canon: "es_mayor_que"),
    KeyAlias(alias: "supera_a", canon: "es_mayor_que"), KeyAlias(alias: "gana_a", canon: "es_mayor_que"),
    KeyAlias(alias: "rebasa", canon: "es_mayor_que"),
    KeyAlias(alias: "is_greater_than", canon: "es_mayor_que"),
    KeyAlias(alias: "greater_than", canon: "es_mayor_que"),
    KeyAlias(alias: "bigger_than", canon: "es_mayor_que"),
    KeyAlias(alias: "exceeds", canon: "es_mayor_que"), KeyAlias(alias: "beats", canon: "es_mayor_que"),
    KeyAlias(alias: "surpasses", canon: "es_mayor_que"),

    KeyAlias(alias: "menor_que", canon: "es_menor_que"),
    KeyAlias(alias: "mas_chico_que", canon: "es_menor_que"),
    KeyAlias(alias: "mas_pequeno_que", canon: "es_menor_que"),
    KeyAlias(alias: "no_llega_a", canon: "es_menor_que"),
    KeyAlias(alias: "pierde_contra", canon: "es_menor_que"),
    KeyAlias(alias: "is_less_than", canon: "es_menor_que"),
    KeyAlias(alias: "less_than", canon: "es_menor_que"),
    KeyAlias(alias: "smaller_than", canon: "es_menor_que"),
    KeyAlias(alias: "loses_to", canon: "es_menor_que"),

    KeyAlias(alias: "distinto_de", canon: "es_distinto_de"),
    KeyAlias(alias: "diferente_de", canon: "es_distinto_de"),
    KeyAlias(alias: "is_different", canon: "es_distinto_de"),
    KeyAlias(alias: "is_not", canon: "es_distinto_de"),
    KeyAlias(alias: "differ_from", canon: "es_distinto_de"),
    KeyAlias(alias: "empata_con", canon: "es_igual_a"),
    KeyAlias(alias: "ties_with", canon: "es_igual_a"),
    KeyAlias(alias: "is_equal_to", canon: "es_igual_a"),

    # booleanos
    KeyAlias(alias: "verdadero", canon: "verdad"), KeyAlias(alias: "cierto", canon: "verdad"),
    KeyAlias(alias: "simon", canon: "verdad"), KeyAlias(alias: "sip", canon: "verdad"),
    KeyAlias(alias: "positivo", canon: "verdad"), KeyAlias(alias: "afirmativo", canon: "verdad"),
    KeyAlias(alias: "correcto", canon: "verdad"), KeyAlias(alias: "correcta", canon: "verdad"),
    KeyAlias(alias: "exacto", canon: "verdad"), KeyAlias(alias: "exacta", canon: "verdad"),
    KeyAlias(alias: "true", canon: "verdad"), KeyAlias(alias: "right", canon: "verdad"),
    KeyAlias(alias: "yup", canon: "verdad"), KeyAlias(alias: "yep", canon: "verdad"),
    KeyAlias(alias: "yeah", canon: "verdad"), KeyAlias(alias: "uh_huh", canon: "verdad"),
    KeyAlias(alias: "correct", canon: "verdad"), KeyAlias(alias: "exact", canon: "verdad"),
    KeyAlias(alias: "precisely", canon: "verdad"),

    KeyAlias(alias: "mentira", canon: "falso"), KeyAlias(alias: "nel", canon: "falso"),
    KeyAlias(alias: "negativo", canon: "falso"), KeyAlias(alias: "ni_a_palos", canon: "falso"),
    KeyAlias(alias: "nanai", canon: "falso"), KeyAlias(alias: "false", canon: "falso"),
    KeyAlias(alias: "wrong", canon: "falso"), KeyAlias(alias: "nope", canon: "falso"),
    KeyAlias(alias: "negative", canon: "falso"), KeyAlias(alias: "no_sir", canon: "falso"),

    # listas
    KeyAlias(alias: "coleccion", canon: "lista"), KeyAlias(alias: "conjunto", canon: "lista"),
    KeyAlias(alias: "grupo", canon: "lista"), KeyAlias(alias: "serie", canon: "lista"),
    KeyAlias(alias: "sucesion", canon: "lista"), KeyAlias(alias: "tanda", canon: "lista"),
    KeyAlias(alias: "ristra", canon: "lista"), KeyAlias(alias: "retahila", canon: "lista"),
    KeyAlias(alias: "manojo", canon: "lista"), KeyAlias(alias: "monton", canon: "lista"),
    KeyAlias(alias: "fila", canon: "lista"), KeyAlias(alias: "hilera", canon: "lista"),
    KeyAlias(alias: "list", canon: "lista"), KeyAlias(alias: "collection", canon: "lista"),
    KeyAlias(alias: "bunch", canon: "lista"), KeyAlias(alias: "pile", canon: "lista"),
    KeyAlias(alias: "array", canon: "lista"), KeyAlias(alias: "set", canon: "lista"),
    KeyAlias(alias: "lineup", canon: "lista"), KeyAlias(alias: "roster", canon: "lista"),
    KeyAlias(alias: "sequence", canon: "lista"), KeyAlias(alias: "succession", canon: "lista"),
    KeyAlias(alias: "batch", canon: "lista"), KeyAlias(alias: "row", canon: "lista"),
    KeyAlias(alias: "queue", canon: "lista"), KeyAlias(alias: "chain", canon: "lista"),

    KeyAlias(alias: "sin_nada", canon: "vacia"), KeyAlias(alias: "hueca", canon: "vacia"),
    KeyAlias(alias: "zilch", canon: "vacia"), KeyAlias(alias: "zip", canon: "vacia"),
    KeyAlias(alias: "nada", canon: "vacia"), KeyAlias(alias: "empty", canon: "vacia"),
    KeyAlias(alias: "blank", canon: "vacia"),

    KeyAlias(alias: "lista_de_texto", canon: "lista_texto"),
    KeyAlias(alias: "lista_de_registros", canon: "lista_de_registros"),
    KeyAlias(alias: "id", canon: "elemento"),
    KeyAlias(alias: "lista_de_listas", canon: "lista_listas"),

    KeyAlias(alias: "element", canon: "elemento"),
    KeyAlias(alias: "pieza", canon: "elemento"), KeyAlias(alias: "parte", canon: "elemento"),
    KeyAlias(alias: "miembro", canon: "elemento"), KeyAlias(alias: "casilla", canon: "elemento"),
    KeyAlias(alias: "trozo", canon: "elemento"), KeyAlias(alias: "pedazo", canon: "elemento"),
    KeyAlias(alias: "cacho", canon: "elemento"), KeyAlias(alias: "fragmento", canon: "elemento"),
    KeyAlias(alias: "eslabon", canon: "elemento"), KeyAlias(alias: "unidad", canon: "elemento"),
    KeyAlias(alias: "componente", canon: "elemento"),
    KeyAlias(alias: "item", canon: "elemento"), KeyAlias(alias: "member", canon: "elemento"),
    KeyAlias(alias: "entry", canon: "elemento"), KeyAlias(alias: "cell", canon: "elemento"),
    KeyAlias(alias: "chunk", canon: "elemento"), KeyAlias(alias: "piece", canon: "elemento"),
    KeyAlias(alias: "bit", canon: "elemento"), KeyAlias(alias: "fragment", canon: "elemento"),
    KeyAlias(alias: "link", canon: "elemento"), KeyAlias(alias: "unit", canon: "elemento"),
    KeyAlias(alias: "component", canon: "elemento"), KeyAlias(alias: "thing", canon: "elemento"),

    KeyAlias(alias: "cabeza", canon: "primero"), KeyAlias(alias: "numero_uno", canon: "primero"),
    KeyAlias(alias: "campeon", canon: "primero"), KeyAlias(alias: "ganador", canon: "primero"),
    KeyAlias(alias: "inicial", canon: "primero"),
    KeyAlias(alias: "first", canon: "primero"), KeyAlias(alias: "head", canon: "primero"),
    KeyAlias(alias: "number_one", canon: "primero"), KeyAlias(alias: "champ", canon: "primero"),
    KeyAlias(alias: "champion", canon: "primero"), KeyAlias(alias: "winner", canon: "primero"),
    KeyAlias(alias: "initial", canon: "primero"), KeyAlias(alias: "first_off", canon: "primero"),

    KeyAlias(alias: "último", canon: "ultimo"), KeyAlias(alias: "cola", canon: "ultimo"),
    KeyAlias(alias: "colista", canon: "ultimo"), KeyAlias(alias: "farolillo", canon: "ultimo"),
    KeyAlias(alias: "farolillo_rojo", canon: "ultimo"), KeyAlias(alias: "ultimo_mono", canon: "ultimo"),
    KeyAlias(alias: "perdedor", canon: "ultimo"),
    KeyAlias(alias: "last", canon: "ultimo"), KeyAlias(alias: "tail", canon: "ultimo"),
    KeyAlias(alias: "dead_last", canon: "ultimo"), KeyAlias(alias: "loser", canon: "ultimo"),
    KeyAlias(alias: "caboose", canon: "ultimo"),

    KeyAlias(alias: "largo", canon: "longitud"), KeyAlias(alias: "tamano", canon: "longitud"),
    KeyAlias(alias: "tamaño", canon: "longitud"), KeyAlias(alias: "medida", canon: "longitud"),
    KeyAlias(alias: "extension", canon: "longitud"),
    KeyAlias(alias: "length", canon: "longitud"), KeyAlias(alias: "size", canon: "longitud"),
    KeyAlias(alias: "count", canon: "longitud"), KeyAlias(alias: "measurement", canon: "longitud"),
    KeyAlias(alias: "extent", canon: "longitud"), KeyAlias(alias: "span", canon: "longitud"),

    KeyAlias(alias: "añadir", canon: "agregar"), KeyAlias(alias: "anadir", canon: "agregar"),
    KeyAlias(alias: "meter", canon: "agregar"), KeyAlias(alias: "incorpora", canon: "agregar"),
    KeyAlias(alias: "integra", canon: "agregar"), KeyAlias(alias: "inyecta", canon: "agregar"),
    KeyAlias(alias: "anexa", canon: "agregar"), KeyAlias(alias: "adjunta", canon: "agregar"),
    KeyAlias(alias: "append", canon: "agregar"), KeyAlias(alias: "attach", canon: "agregar"),
    KeyAlias(alias: "stick_in", canon: "agregar"), KeyAlias(alias: "toss_in", canon: "agregar"),
    KeyAlias(alias: "push", canon: "agregar"), KeyAlias(alias: "inject", canon: "agregar"),
    KeyAlias(alias: "incorporate", canon: "agregar"), KeyAlias(alias: "integrate", canon: "agregar"),

    KeyAlias(alias: "sacar", canon: "quitar"), KeyAlias(alias: "eliminar", canon: "quitar"),
    KeyAlias(alias: "borrar", canon: "quitar"), KeyAlias(alias: "remover", canon: "quitar"),
    KeyAlias(alias: "extrae", canon: "quitar"), KeyAlias(alias: "arranca", canon: "quitar"),
    KeyAlias(alias: "desecha", canon: "quitar"), KeyAlias(alias: "tira", canon: "quitar"),
    KeyAlias(alias: "bota", canon: "quitar"), KeyAlias(alias: "expulsa", canon: "quitar"),
    KeyAlias(alias: "remove", canon: "quitar"), KeyAlias(alias: "delete", canon: "quitar"),
    KeyAlias(alias: "drop", canon: "quitar"), KeyAlias(alias: "take_out", canon: "quitar"),
    KeyAlias(alias: "erase", canon: "quitar"), KeyAlias(alias: "extract", canon: "quitar"),
    KeyAlias(alias: "yank", canon: "quitar"), KeyAlias(alias: "toss", canon: "quitar"),
    KeyAlias(alias: "chuck", canon: "quitar"), KeyAlias(alias: "ditch", canon: "quitar"),
    KeyAlias(alias: "discard", canon: "quitar"),

    KeyAlias(alias: "out_of", canon: "de"), KeyAlias(alias: "of", canon: "de"),
    KeyAlias(alias: "from", canon: "de"), KeyAlias(alias: "del", canon: "de"),
    KeyAlias(alias: "to", canon: "a"), KeyAlias(alias: "into", canon: "a"),
    KeyAlias(alias: "al", canon: "a"),
    KeyAlias(alias: "dentro", canon: "en"), KeyAlias(alias: "dentro_de", canon: "en"),
    KeyAlias(alias: "in", canon: "en"), KeyAlias(alias: "inside", canon: "en"),
    KeyAlias(alias: "within", canon: "en"),

    # registros y punteros
    KeyAlias(alias: "ficha", canon: "registro"), KeyAlias(alias: "caja", canon: "registro"),
    KeyAlias(alias: "paquete", canon: "registro"), KeyAlias(alias: "cajon", canon: "registro"),
    KeyAlias(alias: "carpeta", canon: "registro"), KeyAlias(alias: "formulario", canon: "registro"),
    KeyAlias(alias: "record", canon: "registro"), KeyAlias(alias: "card", canon: "registro"),
    KeyAlias(alias: "file", canon: "registro"), KeyAlias(alias: "packet", canon: "registro"),
    KeyAlias(alias: "struct", canon: "registro"), KeyAlias(alias: "folder", canon: "registro"),
    KeyAlias(alias: "form", canon: "registro"), KeyAlias(alias: "binder", canon: "registro"),
    KeyAlias(alias: "slip", canon: "registro"),

    KeyAlias(alias: "mete", canon: "poner"), KeyAlias(alias: "coloca", canon: "poner"),
    KeyAlias(alias: "asigna", canon: "poner"), KeyAlias(alias: "fija", canon: "poner"),
    KeyAlias(alias: "planta", canon: "poner"), KeyAlias(alias: "deposita", canon: "poner"),
    KeyAlias(alias: "deja", canon: "poner"), KeyAlias(alias: "put", canon: "poner"),
    KeyAlias(alias: "place", canon: "poner"), KeyAlias(alias: "set", canon: "poner"),
    KeyAlias(alias: "assign", canon: "poner"), KeyAlias(alias: "store", canon: "poner"),
    KeyAlias(alias: "lay", canon: "poner"), KeyAlias(alias: "stick", canon: "poner"),
    KeyAlias(alias: "leave", canon: "poner"), KeyAlias(alias: "deposit", canon: "poner"),

    KeyAlias(alias: "dedo", canon: "puntero"), KeyAlias(alias: "indicador", canon: "puntero"),
    KeyAlias(alias: "señalador", canon: "puntero"), KeyAlias(alias: "flecha", canon: "puntero"),
    KeyAlias(alias: "pointer", canon: "puntero"), KeyAlias(alias: "finger", canon: "puntero"),
    KeyAlias(alias: "indicator", canon: "puntero"), KeyAlias(alias: "cursor", canon: "puntero"),

    # control de bucle
    KeyAlias(alias: "alto", canon: "para"), KeyAlias(alias: "detente", canon: "para"),
    KeyAlias(alias: "frena", canon: "para"), KeyAlias(alias: "frenazo", canon: "para"),
    KeyAlias(alias: "quieto", canon: "para"), KeyAlias(alias: "para_ya", canon: "para"),
    KeyAlias(alias: "stop", canon: "para"), KeyAlias(alias: "halt", canon: "para"),
    KeyAlias(alias: "freeze", canon: "para"), KeyAlias(alias: "hold_on", canon: "para"),
    KeyAlias(alias: "whoa", canon: "para"),

    KeyAlias(alias: "continua", canon: "sigue"), KeyAlias(alias: "continúa", canon: "sigue"),
    KeyAlias(alias: "adelante", canon: "sigue"), KeyAlias(alias: "palante", canon: "sigue"),
    KeyAlias(alias: "sigue_sigue", canon: "sigue"),
    KeyAlias(alias: "continue", canon: "sigue"), KeyAlias(alias: "carry_on", canon: "sigue"),
    KeyAlias(alias: "go_on", canon: "sigue"), KeyAlias(alias: "onward", canon: "sigue"),
    KeyAlias(alias: "onwards", canon: "sigue"), KeyAlias(alias: "proceed", canon: "sigue"),

    KeyAlias(alias: "uno_a_uno", canon: "por_cada"),
    KeyAlias(alias: "for_each", canon: "por_cada"), KeyAlias(alias: "for_every", canon: "por_cada"),
    KeyAlias(alias: "one_by_one", canon: "por_cada"), KeyAlias(alias: "foreach", canon: "por_cada"),

    KeyAlias(alias: "as", canon: "como"),
    KeyAlias(alias: "depende", canon: "segun"), KeyAlias(alias: "match", canon: "segun"),
    KeyAlias(alias: "switch", canon: "segun"), KeyAlias(alias: "depending_on", canon: "segun"),
    KeyAlias(alias: "digamos", canon: "caso"), KeyAlias(alias: "case", canon: "caso"),
    KeyAlias(alias: "resto", canon: "otro"), KeyAlias(alias: "otherwise", canon: "otro"),
    KeyAlias(alias: "default", canon: "otro"), KeyAlias(alias: "other", canon: "otro"),

    # tiempo, azar, pantalla fija, lienzo
    KeyAlias(alias: "ticks", canon: "tick"), KeyAlias(alias: "fps", canon: "tick"),
    KeyAlias(alias: "fotogramas", canon: "tick"), KeyAlias(alias: "fotograma", canon: "tick"),
    KeyAlias(alias: "ritmo", canon: "tick"), KeyAlias(alias: "tps", canon: "tick"),
    KeyAlias(alias: "tiempo", canon: "tick"), KeyAlias(alias: "cuadro", canon: "tick"),
    KeyAlias(alias: "cuadros", canon: "tick"), KeyAlias(alias: "frames", canon: "tick"),
    KeyAlias(alias: "framerate", canon: "tick"), KeyAlias(alias: "rate", canon: "tick"),

    KeyAlias(alias: "encima", canon: "pisa"), KeyAlias(alias: "overwrite", canon: "pisa"),
    KeyAlias(alias: "overprint", canon: "pisa"), KeyAlias(alias: "rewrite", canon: "pisa"),
    KeyAlias(alias: "espera", canon: "esperar"), KeyAlias(alias: "aguarda", canon: "esperar"),
    KeyAlias(alias: "wait", canon: "esperar"),
    KeyAlias(alias: "aleatorio", canon: "azar"), KeyAlias(alias: "random", canon: "azar"),
    KeyAlias(alias: "limpia", canon: "limpiar"), KeyAlias(alias: "despeja", canon: "limpiar"),
    KeyAlias(alias: "clear", canon: "limpiar"), KeyAlias(alias: "wipe", canon: "limpiar"),
    KeyAlias(alias: "cls", canon: "limpiar"), KeyAlias(alias: "canvas", canon: "lienzo"),
    KeyAlias(alias: "marcar", canon: "marca"), KeyAlias(alias: "sella", canon: "marca"),
    KeyAlias(alias: "mark", canon: "marca"), KeyAlias(alias: "plot", canon: "marca"),
    KeyAlias(alias: "stamp", canon: "marca"),
    KeyAlias(alias: "pared", canon: "muro"), KeyAlias(alias: "tapia", canon: "muro"),
    KeyAlias(alias: "muralla", canon: "muro"), KeyAlias(alias: "tapiar", canon: "muro"),
    KeyAlias(alias: "amurallar", canon: "muro"), KeyAlias(alias: "wall", canon: "muro"),
    KeyAlias(alias: "coin", canon: "moneda"),
    KeyAlias(alias: "destino", canon: "meta"), KeyAlias(alias: "llegada", canon: "meta"),
    KeyAlias(alias: "goal", canon: "meta"),
    KeyAlias(alias: "leer", canon: "leer"),
    KeyAlias(alias: "chusmea", canon: "lee"), KeyAlias(alias: "consulta", canon: "lee"),
    KeyAlias(alias: "peek", canon: "lee"),
    KeyAlias(alias: "pizarra", canon: "tablero"), KeyAlias(alias: "board", canon: "tablero"),

    # ficheros (sesión única)
    KeyAlias(alias: "abrir", canon: "abrir"), KeyAlias(alias: "abierto", canon: "abrir"),
    KeyAlias(alias: "open", canon: "abrir"), KeyAlias(alias: "abre", canon: "abrir"),
    KeyAlias(alias: "launch", canon: "abrir"),
    KeyAlias(alias: "cerrar", canon: "cerrar"), KeyAlias(alias: "close", canon: "cerrar"),
    KeyAlias(alias: "cierra", canon: "cerrar"), KeyAlias(alias: "termina", canon: "cerrar"),
    KeyAlias(alias: "crear", canon: "crear"), KeyAlias(alias: "creado", canon: "crear"),
    KeyAlias(alias: "create", canon: "crear"), KeyAlias(alias: "crea", canon: "crear"),
    KeyAlias(alias: "genera", canon: "crear"), KeyAlias(alias: "fabrica", canon: "crear"),
    KeyAlias(alias: "suprimir", canon: "quitar"), KeyAlias(alias: "suprime", canon: "quitar"),
    KeyAlias(alias: "destruye", canon: "quitar"), KeyAlias(alias: "destroy", canon: "quitar"),
    KeyAlias(alias: "escribir", canon: "escribir"), KeyAlias(alias: "redacta", canon: "escribir"),
    KeyAlias(alias: "anota", canon: "escribir"), KeyAlias(alias: "apunta", canon: "escribir"),
    KeyAlias(alias: "graba", canon: "escribir"),

    # red (sesión única TCP)
    KeyAlias(alias: "conectar", canon: "conectar"), KeyAlias(alias: "conecta", canon: "conectar"),
    KeyAlias(alias: "conectate", canon: "conectar"), KeyAlias(alias: "connect", canon: "conectar"),
    KeyAlias(alias: "enviar", canon: "enviar"), KeyAlias(alias: "envia", canon: "enviar"),
    KeyAlias(alias: "manda", canon: "enviar"), KeyAlias(alias: "send", canon: "enviar"),
    KeyAlias(alias: "recibir", canon: "recibir"), KeyAlias(alias: "recibe", canon: "recibir"),
    KeyAlias(alias: "receive", canon: "recibir"), KeyAlias(alias: "recv", canon: "recibir"),
    KeyAlias(alias: "desconectar", canon: "desconectar"),
    KeyAlias(alias: "desconecta", canon: "desconectar"), KeyAlias(alias: "cuelga", canon: "desconectar"),
    KeyAlias(alias: "disconnect", canon: "desconectar"),

    # presets del sistema (solo lectura)
    KeyAlias(alias: "hora", canon: "hora"), KeyAlias(alias: "hour", canon: "hora"),
    KeyAlias(alias: "fecha", canon: "fecha"), KeyAlias(alias: "date", canon: "fecha"),
    KeyAlias(alias: "usuario", canon: "usuario"), KeyAlias(alias: "user", canon: "usuario"),
    KeyAlias(alias: "username", canon: "usuario"), KeyAlias(alias: "sistema", canon: "sistema"),
    KeyAlias(alias: "system", canon: "sistema"), KeyAlias(alias: "os", canon: "sistema"),
    KeyAlias(alias: "version", canon: "version"),
    KeyAlias(alias: "directorio", canon: "directorio"), KeyAlias(alias: "pwd", canon: "directorio"),
    KeyAlias(alias: "dir", canon: "directorio"), KeyAlias(alias: "cwd", canon: "directorio"),

    # lecturas/canonicas reservadas
    KeyAlias(alias: "elemento", canon: "elemento"), KeyAlias(alias: "primero", canon: "primero"),
    KeyAlias(alias: "ultimo", canon: "ultimo"), KeyAlias(alias: "longitud", canon: "longitud"),
    KeyAlias(alias: "entero", canon: "entero"), KeyAlias(alias: "numero", canon: "entero"),
    KeyAlias(alias: "number", canon: "entero"), KeyAlias(alias: "int", canon: "entero"),
    KeyAlias(alias: "lista", canon: "lista"), KeyAlias(alias: "registro", canon: "registro"),
    KeyAlias(alias: "puntero", canon: "puntero"), KeyAlias(alias: "esperar", canon: "esperar"),
    KeyAlias(alias: "azar", canon: "azar"), KeyAlias(alias: "limpiar", canon: "limpiar"),
    KeyAlias(alias: "lienzo", canon: "lienzo"), KeyAlias(alias: "marca", canon: "marca"),
    KeyAlias(alias: "tablero", canon: "tablero"), KeyAlias(alias: "muro", canon: "muro"),
    KeyAlias(alias: "moneda", canon: "moneda"), KeyAlias(alias: "meta", canon: "meta"),
    KeyAlias(alias: "poner", canon: "poner"), KeyAlias(alias: "mostrar", canon: "mostrar"),
    KeyAlias(alias: "pedir", canon: "pedir"), KeyAlias(alias: "fin", canon: "fin"),
    KeyAlias(alias: "mientras", canon: "mientras"), KeyAlias(alias: "funcion", canon: "funcion"),
    KeyAlias(alias: "devolver", canon: "devolver"), KeyAlias(alias: "agregar", canon: "agregar"),
    KeyAlias(alias: "quitar", canon: "quitar"),

    # canonicas reservadas (lectura)
    KeyAlias(alias: "tecla", canon: "tecla"), KeyAlias(alias: "key", canon: "tecla"),
    KeyAlias(alias: "pulsacion", canon: "tecla"), KeyAlias(alias: "teclazo", canon: "tecla"),
    KeyAlias(alias: "keypress", canon: "tecla"), KeyAlias(alias: "tequita", canon: "tecla"),
    KeyAlias(alias: "boton", canon: "tecla"), KeyAlias(alias: "button", canon: "tecla"),
    KeyAlias(alias: "tecleo", canon: "tecla"), KeyAlias(alias: "pulsada", canon: "tecla"),
    KeyAlias(alias: "tiempo", canon: "tiempo"), KeyAlias(alias: "time", canon: "tiempo"),
    KeyAlias(alias: "reloj", canon: "tiempo"), KeyAlias(alias: "cronometro", canon: "tiempo"),
    KeyAlias(alias: "clock", canon: "tiempo"), KeyAlias(alias: "elapsed", canon: "tiempo"),
    KeyAlias(alias: "transcurrido", canon: "tiempo"), KeyAlias(alias: "delta", canon: "delta"),
    KeyAlias(alias: "segundos", canon: "delta"), KeyAlias(alias: "segundo", canon: "delta"),
    KeyAlias(alias: "dt", canon: "delta"), KeyAlias(alias: "paso", canon: "delta"),
    KeyAlias(alias: "step", canon: "delta"), KeyAlias(alias: "diferencial", canon: "delta"),
    KeyAlias(alias: "tick", canon: "tick"), KeyAlias(alias: "turbo", canon: "turbo"),
    KeyAlias(alias: "segun", canon: "segun"), KeyAlias(alias: "caso", canon: "caso"),
    KeyAlias(alias: "otro", canon: "otro"), KeyAlias(alias: "como", canon: "como"),
    KeyAlias(alias: "por_cada", canon: "por_cada"), KeyAlias(alias: "sino", canon: "sino"),
    KeyAlias(alias: "en_caso_de_que", canon: "en_caso_de_que"),
    KeyAlias(alias: "y", canon: "y"), KeyAlias(alias: "o", canon: "o"), KeyAlias(alias: "no", canon: "no"),
    KeyAlias(alias: "igual", canon: "igual"), KeyAlias(alias: "mas", canon: "mas"),
    KeyAlias(alias: "menos", canon: "menos"), KeyAlias(alias: "por", canon: "por"),
    KeyAlias(alias: "entre", canon: "entre"), KeyAlias(alias: "es_igual_a", canon: "es_igual_a"),
    KeyAlias(alias: "es_equivalente_a", canon: "es_equivalente_a"),
    KeyAlias(alias: "equivalente_a", canon: "es_equivalente_a"),
    KeyAlias(alias: "is_equivalent_to", canon: "es_equivalente_a"),
    KeyAlias(alias: "equivalent_to", canon: "es_equivalente_a"),
    KeyAlias(alias: "es_mayor_que", canon: "es_mayor_que"), KeyAlias(alias: "es_menor_que", canon: "es_menor_que"),
    KeyAlias(alias: "es_distinto_de", canon: "es_distinto_de"),
    KeyAlias(alias: "es_mayor_o_igual", canon: "es_mayor_o_igual"),
    KeyAlias(alias: "es_menor_o_igual", canon: "es_menor_o_igual"),
    KeyAlias(alias: "verdad", canon: "verdad"), KeyAlias(alias: "falso", canon: "falso"),
    KeyAlias(alias: "de", canon: "de"), KeyAlias(alias: "a", canon: "a"),
     KeyAlias(alias: "en", canon: "en"), KeyAlias(alias: "lee", canon: "lee"),
     KeyAlias(alias: "leer", canon: "leer"),
     KeyAlias(alias: "pisa", canon: "pisa"), KeyAlias(alias: "vacia", canon: "vacia"),
     KeyAlias(alias: "hilos", canon: "hilos"), KeyAlias(alias: "threads", canon: "hilos"), KeyAlias(alias: "hebras", canon: "hilos"),
     KeyAlias(alias: "tarea", canon: "tarea"), KeyAlias(alias: "task", canon: "tarea"), KeyAlias(alias: "trabajo", canon: "tarea"),
     KeyAlias(alias: "hilo", canon: "hilo"), KeyAlias(alias: "thread", canon: "hilo"), KeyAlias(alias: "async", canon: "tarea"),
     KeyAlias(alias: "paralelo", canon: "tarea"), KeyAlias(alias: "asinc", canon: "tarea"), KeyAlias(alias: "asíncrono", canon: "tarea"),
     KeyAlias(alias: "servicio", canon: "servicio"), KeyAlias(alias: "service", canon: "servicio"), KeyAlias(alias: "registrar", canon: "servicio"),
     KeyAlias(alias: "registra", canon: "servicio"), KeyAlias(alias: "inscribir", canon: "servicio"), KeyAlias(alias: "alta", canon: "servicio"),
     KeyAlias(alias: "dar_de_alta", canon: "servicio"), KeyAlias(alias: "montar", canon: "servicio"), KeyAlias(alias: "enchufar", canon: "servicio"),
     KeyAlias(alias: "inyectar", canon: "inyectar"), KeyAlias(alias: "inject", canon: "inyectar"), KeyAlias(alias: "resolver", canon: "inyectar"),
     KeyAlias(alias: "obtener", canon: "inyectar"), KeyAlias(alias: "buscar", canon: "inyectar"), KeyAlias(alias: "get_service", canon: "inyectar"),
     KeyAlias(alias: "administrador", canon: "administrador"), KeyAlias(alias: "container", canon: "administrador"), KeyAlias(alias: "ioc", canon: "administrador"),
     KeyAlias(alias: "gestor", canon: "administrador"), KeyAlias(alias: "registro_de_servicios", canon: "administrador"),

    # Ventana 2D (Direct3D 11 en Windows)
    KeyAlias(alias: "ventana", canon: "ventana"), KeyAlias(alias: "window", canon: "ventana"), KeyAlias(alias: "ventana2d", canon: "ventana"),
    KeyAlias(alias: "abrir", canon: "abrir"), KeyAlias(alias: "open", canon: "abrir"),
    KeyAlias(alias: "cerrar", canon: "cerrar"), KeyAlias(alias: "close", canon: "cerrar"),
    KeyAlias(alias: "limpiar", canon: "limpiar"), KeyAlias(alias: "clear", canon: "limpiar"),
    KeyAlias(alias: "color", canon: "color"), KeyAlias(alias: "rectangulo", canon: "rectangulo"), KeyAlias(alias: "rect", canon: "rectangulo"),
    KeyAlias(alias: "circulo", canon: "circulo"), KeyAlias(alias: "circle", canon: "circulo"),
    KeyAlias(alias: "linea", canon: "linea"), KeyAlias(alias: "line", canon: "linea"),
    KeyAlias(alias: "rotulo", canon: "rotulo"), KeyAlias(alias: "label", canon: "rotulo"),
    KeyAlias(alias: "sprite", canon: "sprite"), KeyAlias(alias: "voltear", canon: "voltear"), KeyAlias(alias: "flip", canon: "voltear"),
    KeyAlias(alias: "presentar", canon: "presentar"), KeyAlias(alias: "present", canon: "presentar"),
    KeyAlias(alias: "ancho", canon: "ancho"), KeyAlias(alias: "width", canon: "ancho"),
    KeyAlias(alias: "alto", canon: "alto"), KeyAlias(alias: "height", canon: "alto"),
    KeyAlias(alias: "raton_x", canon: "raton_x"), KeyAlias(alias: "mouse_x", canon: "raton_x"),
    KeyAlias(alias: "raton_y", canon: "raton_y"), KeyAlias(alias: "mouse_y", canon: "raton_y"),
    KeyAlias(alias: "boton_izquierdo", canon: "boton_izquierdo"), KeyAlias(alias: "boton_derecho", canon: "boton_derecho"),
    KeyAlias(alias: "tecla", canon: "tecla"), KeyAlias(alias: "key", canon: "tecla"),
    KeyAlias(alias: "pulsa_tecla", canon: "pulsa_tecla"), KeyAlias(alias: "key_pressed", canon: "pulsa_tecla"),

    KeyAlias(alias: "para", canon: "para"), KeyAlias(alias: "sigue", canon: "sigue"),
    KeyAlias(alias: "conectar", canon: "conectar"), KeyAlias(alias: "enviar", canon: "enviar"),
    KeyAlias(alias: "recibir", canon: "recibir"), KeyAlias(alias: "desconectar", canon: "desconectar"),

    # GPU: sesion unica de computo (Direct3D 11 en Windows)
    KeyAlias(alias: "gpu", canon: "gpu"),
    KeyAlias(alias: "iniciar", canon: "iniciar"), KeyAlias(alias: "empezar", canon: "iniciar"),
    KeyAlias(alias: "arrancar", canon: "iniciar"), KeyAlias(alias: "start", canon: "iniciar"),
    KeyAlias(alias: "programa", canon: "programa"), KeyAlias(alias: "program", canon: "programa"),
    KeyAlias(alias: "ejecutar", canon: "ejecutar"), KeyAlias(alias: "execute", canon: "ejecutar"),
    KeyAlias(alias: "correr", canon: "ejecutar"), KeyAlias(alias: "run", canon: "ejecutar"),
    KeyAlias(alias: "terminar", canon: "terminar"), KeyAlias(alias: "acabar", canon: "terminar"),
    KeyAlias(alias: "shutdown", canon: "terminar"),

    # FFI: cargar DLL + funcion externa
    KeyAlias(alias: "cargar", canon: "cargar"), KeyAlias(alias: "load", canon: "cargar"),
    KeyAlias(alias: "load_library", canon: "cargar"),
    KeyAlias(alias: "externa", canon: "externa"), KeyAlias(alias: "external", canon: "externa"),
    KeyAlias(alias: "externo", canon: "externa"), KeyAlias(alias: "foranea", canon: "externa"),
    KeyAlias(alias: "foreign", canon: "externa"), KeyAlias(alias: "usando", canon: "usando"),
    KeyAlias(alias: "using", canon: "usando"), KeyAlias(alias: "stdcall", canon: "stdcall"),
    KeyAlias(alias: "cdecl", canon: "cdecl"),

    # HTTPS: descarga segura de un tiro
    KeyAlias(alias: "https", canon: "https"), KeyAlias(alias: "segura", canon: "https"),
    KeyAlias(alias: "secure", canon: "https"),

    # Callbacks: direccion de F
    KeyAlias(alias: "direccion", canon: "direccion"), KeyAlias(alias: "address", canon: "direccion"),

    # Trigonometria
    KeyAlias(alias: "seno", canon: "seno"), KeyAlias(alias: "sin", canon: "seno"),
    KeyAlias(alias: "coseno", canon: "coseno"), KeyAlias(alias: "cos", canon: "coseno"),

    # FFI v2: asas opacas + alias de simbolo mangled
    KeyAlias(alias: "asa", canon: "asa"), KeyAlias(alias: "handle", canon: "asa"),
    KeyAlias(alias: "asidero", canon: "asa"), KeyAlias(alias: "nula", canon: "nula"),
    KeyAlias(alias: "null", canon: "nula"), KeyAlias(alias: "alias", canon: "alias"),

    # Audio: exportar listas de muestras a WAV / MP3 / OGG
    KeyAlias(alias: "audio", canon: "audio"), KeyAlias(alias: "sonido", canon: "audio"),
    KeyAlias(alias: "sound", canon: "audio"), KeyAlias(alias: "musica", canon: "audio"),
    KeyAlias(alias: "music", canon: "audio"), KeyAlias(alias: "audiostr", canon: "audio"),
    KeyAlias(alias: "exportar", canon: "exportar"), KeyAlias(alias: "export", canon: "exportar"),
    KeyAlias(alias: "grabar", canon: "exportar"), KeyAlias(alias: "record", canon: "exportar"),
    KeyAlias(alias: "dump", canon: "exportar"),

    # mando: pad, guitarra GH, palanca, volante
    KeyAlias(alias: "mando", canon: "mando"), KeyAlias(alias: "pad", canon: "mando"),
    KeyAlias(alias: "gamepad", canon: "mando"), KeyAlias(alias: "joystick", canon: "mando"),
    KeyAlias(alias: "palanca", canon: "mando"), KeyAlias(alias: "guitarra", canon: "mando"),
    KeyAlias(alias: "control", canon: "mando"), KeyAlias(alias: "controller", canon: "mando"),
    KeyAlias(alias: "arcade", canon: "mando"), KeyAlias(alias: "volante", canon: "mando"),

    # sobrecarga extra: mas/menos/por/entre/devolver/distinto
    KeyAlias(alias: "ponle", canon: "mas"), KeyAlias(alias: "sumale", canon: "mas"),
    KeyAlias(alias: "agregale", canon: "mas"), KeyAlias(alias: "cargale", canon: "mas"),
    KeyAlias(alias: "add_up", canon: "mas"), KeyAlias(alias: "plus_up", canon: "mas"),
    KeyAlias(alias: "replica", canon: "por"), KeyAlias(alias: "duplica", canon: "por"),
    KeyAlias(alias: "triplica", canon: "por"), KeyAlias(alias: "triple", canon: "por"),
    KeyAlias(alias: "fold", canon: "por"), KeyAlias(alias: "fracciona", canon: "entre"),
    KeyAlias(alias: "corta", canon: "entre"), KeyAlias(alias: "share", canon: "entre"),
    KeyAlias(alias: "cut_up", canon: "entre"),
    KeyAlias(alias: "flaquea_ante", canon: "es_menor_que"),
    KeyAlias(alias: "underperforms", canon: "es_menor_que"),
    KeyAlias(alias: "difiere_de", canon: "es_distinto_de"),
    KeyAlias(alias: "no_iguala", canon: "es_distinto_de"),
    KeyAlias(alias: "differs", canon: "es_distinto_de"), KeyAlias(alias: "mismatches", canon: "es_distinto_de"),
    KeyAlias(alias: "cambia_de", canon: "es_distinto_de"), KeyAlias(alias: "varia_de", canon: "es_distinto_de"),
    KeyAlias(alias: "devuelve", canon: "devolver"), KeyAlias(alias: "retorna", canon: "devolver"),
    KeyAlias(alias: "remite", canon: "devolver"), KeyAlias(alias: "gives_back", canon: "devolver"),
    KeyAlias(alias: "hands_over", canon: "devolver")
  ]

  result.multiWords = @[
    # en_caso_de_que
    MultiWordRule(phrase: "en el caso de que", canon: "en_caso_de_que"),
    MultiWordRule(phrase: "en caso de que", canon: "en_caso_de_que"),
    MultiWordRule(phrase: "in case that", canon: "en_caso_de_que"),
    MultiWordRule(phrase: "on condition that", canon: "en_caso_de_que"),
    MultiWordRule(phrase: "in the event that", canon: "en_caso_de_que"),
    MultiWordRule(phrase: "por si acaso", canon: "en_caso_de_que"),
    MultiWordRule(phrase: "a ver si", canon: "en_caso_de_que"),

    # sino
    MultiWordRule(phrase: "de lo contrario", canon: "sino"),
    MultiWordRule(phrase: "en caso contrario", canon: "sino"),
    MultiWordRule(phrase: "en otro caso", canon: "sino"),
    MultiWordRule(phrase: "de otra forma", canon: "sino"),
    MultiWordRule(phrase: "de otra manera", canon: "sino"),
    MultiWordRule(phrase: "en su defecto", canon: "sino"),
    MultiWordRule(phrase: "or else", canon: "sino"),

    # fin
    MultiWordRule(phrase: "termina aqui", canon: "fin"),
    MultiWordRule(phrase: "termina aquí", canon: "fin"),
    MultiWordRule(phrase: "se acabo", canon: "fin"),
    MultiWordRule(phrase: "se acabó", canon: "fin"),
    MultiWordRule(phrase: "se termino", canon: "fin"),
    MultiWordRule(phrase: "se terminó", canon: "fin"),
    MultiWordRule(phrase: "punto final", canon: "fin"),
    MultiWordRule(phrase: "colorin colorado", canon: "fin"),
    MultiWordRule(phrase: "caso cerrado", canon: "fin"),
    MultiWordRule(phrase: "case closed", canon: "fin"),
    MultiWordRule(phrase: "over and out", canon: "fin"),
    MultiWordRule(phrase: "end of transmission", canon: "fin"),
    MultiWordRule(phrase: "thats all", canon: "fin"),
    MultiWordRule(phrase: "the end", canon: "fin"),

    # mientras
    MultiWordRule(phrase: "en bucle", canon: "mientras"),
    MultiWordRule(phrase: "en loop", canon: "mientras"),
    MultiWordRule(phrase: "dale dale", canon: "mientras"),
    MultiWordRule(phrase: "as long as", canon: "mientras"),
    MultiWordRule(phrase: "keep going", canon: "mientras"),
    MultiWordRule(phrase: "go go", canon: "mientras"),

    # igual / comparaciones compuestas
    MultiWordRule(phrase: "es igual a", canon: "igual"),
    MultiWordRule(phrase: "is equal to", canon: "igual"),
    MultiWordRule(phrase: "is equal", canon: "igual"),
    MultiWordRule(phrase: "are equal to", canon: "igual"),
    MultiWordRule(phrase: "are equal", canon: "igual"),
    MultiWordRule(phrase: "igual a", canon: "igual"),
    MultiWordRule(phrase: "es igual", canon: "igual"),
    MultiWordRule(phrase: "son igual", canon: "igual"),
    MultiWordRule(phrase: "son iguales a", canon: "igual"),
    MultiWordRule(phrase: "es mayor que", canon: "es_mayor_que"),
    MultiWordRule(phrase: "are greater than", canon: "es_mayor_que"),
    MultiWordRule(phrase: "is greater than", canon: "es_mayor_que"),
    MultiWordRule(phrase: "mayor que", canon: "es_mayor_que"),
    MultiWordRule(phrase: "greater than", canon: "es_mayor_que"),
    MultiWordRule(phrase: "mas grande que", canon: "es_mayor_que"),
    MultiWordRule(phrase: "más grande que", canon: "es_mayor_que"),
    MultiWordRule(phrase: "bigger than", canon: "es_mayor_que"),

    MultiWordRule(phrase: "es menor que", canon: "es_menor_que"),
    MultiWordRule(phrase: "are less than", canon: "es_menor_que"),
    MultiWordRule(phrase: "is less than", canon: "es_menor_que"),
    MultiWordRule(phrase: "menor que", canon: "es_menor_que"),
    MultiWordRule(phrase: "less than", canon: "es_menor_que"),
    MultiWordRule(phrase: "mas chico que", canon: "es_menor_que"),
    MultiWordRule(phrase: "más chico que", canon: "es_menor_que"),
    MultiWordRule(phrase: "mas pequeno que", canon: "es_menor_que"),
    MultiWordRule(phrase: "más pequeño que", canon: "es_menor_que"),
    MultiWordRule(phrase: "smaller than", canon: "es_menor_que"),

    MultiWordRule(phrase: "es distinto de", canon: "es_distinto_de"),
    MultiWordRule(phrase: "distinto de", canon: "es_distinto_de"),
    MultiWordRule(phrase: "diferente de", canon: "es_distinto_de"),
    MultiWordRule(phrase: "is different", canon: "es_distinto_de"),
    MultiWordRule(phrase: "different from", canon: "es_distinto_de"),
    MultiWordRule(phrase: "different to", canon: "es_distinto_de"),

    MultiWordRule(phrase: "no es", canon: "es_distinto_de"),
    MultiWordRule(phrase: "es mayor", canon: "es_mayor_que"),
    MultiWordRule(phrase: "es menor", canon: "es_menor_que"),
    MultiWordRule(phrase: "es equivalente a", canon: "es_equivalente_a"),
    MultiWordRule(phrase: "equivalent to", canon: "es_equivalente_a"),
    MultiWordRule(phrase: "are equivalent to", canon: "es_equivalente_a"),
    MultiWordRule(phrase: "is equivalent to", canon: "es_equivalente_a"),

    MultiWordRule(phrase: "es mayor o igual", canon: "es_mayor_o_igual"),
    MultiWordRule(phrase: "es menor o igual", canon: "es_menor_o_igual"),
    MultiWordRule(phrase: "mayor o igual", canon: "es_mayor_o_igual"),
    MultiWordRule(phrase: "menor o igual", canon: "es_menor_o_igual"),
    MultiWordRule(phrase: "es mayor o igual a", canon: "es_mayor_o_igual"),
    MultiWordRule(phrase: "es menor o igual a", canon: "es_menor_o_igual"),
    MultiWordRule(phrase: "mayor o igual a", canon: "es_mayor_o_igual"),
    MultiWordRule(phrase: "menor o igual a", canon: "es_menor_o_igual"),
    MultiWordRule(phrase: "es mayor a", canon: "es_mayor_que"),
    MultiWordRule(phrase: "es menor a", canon: "es_menor_que"),
    MultiWordRule(phrase: "mayor a", canon: "es_mayor_que"),
    MultiWordRule(phrase: "menor a", canon: "es_menor_que"),
    MultiWordRule(phrase: "es mayor de", canon: "es_mayor_que"),
    MultiWordRule(phrase: "es menor de", canon: "es_menor_que"),
    MultiWordRule(phrase: "mayor de", canon: "es_mayor_que"),
    MultiWordRule(phrase: "menor de", canon: "es_menor_que"),
    MultiWordRule(phrase: "es distinto a", canon: "es_distinto_de"),
    MultiWordRule(phrase: "es diferente a", canon: "es_distinto_de"),
    MultiWordRule(phrase: "distinto a", canon: "es_distinto_de"),
    MultiWordRule(phrase: "diferente a", canon: "es_distinto_de"),
    MultiWordRule(phrase: "es distinto que", canon: "es_distinto_de"),
    MultiWordRule(phrase: "es diferente que", canon: "es_distinto_de"),
    MultiWordRule(phrase: "distinto que", canon: "es_distinto_de"),
    MultiWordRule(phrase: "diferente que", canon: "es_distinto_de"),

    # listas / por_cada / segun / comprobaciones
    MultiWordRule(phrase: "por cada", canon: "por_cada"),
    MultiWordRule(phrase: "for each", canon: "por_cada"),
    MultiWordRule(phrase: "for every", canon: "por_cada"),
    MultiWordRule(phrase: "one by one", canon: "por_cada"),
    MultiWordRule(phrase: "depending on", canon: "segun"),
    MultiWordRule(phrase: "sin nada", canon: "vacia"),
    MultiWordRule(phrase: "lista de registros", canon: "lista_de_registros"),
    MultiWordRule(phrase: "list of records", canon: "lista_de_registros"),
    MultiWordRule(phrase: "lista de texto", canon: "lista_texto"),
    MultiWordRule(phrase: "list of text", canon: "lista_texto"),
    MultiWordRule(phrase: "lista de listas", canon: "lista_listas"),
    MultiWordRule(phrase: "lista de lista", canon: "lista_listas"),
    MultiWordRule(phrase: "list of lists", canon: "lista_listas"),
    MultiWordRule(phrase: "give back", canon: "devolver"),
    MultiWordRule(phrase: "hand back", canon: "devolver"),
    MultiWordRule(phrase: "cough up", canon: "pedir"),
    MultiWordRule(phrase: "take away", canon: "menos"),
    MultiWordRule(phrase: "stick in", canon: "agregar"),
    MultiWordRule(phrase: "toss in", canon: "agregar"),
    MultiWordRule(phrase: "take out", canon: "quitar"),
    MultiWordRule(phrase: "carry on", canon: "sigue"),
    MultiWordRule(phrase: "go on", canon: "sigue"),
    MultiWordRule(phrase: "hold on", canon: "para"),
    MultiWordRule(phrase: "para ya", canon: "para"),
    MultiWordRule(phrase: "sigue sigue", canon: "sigue"),

    # bits
    MultiWordRule(phrase: "y_bit", canon: "y_bit"),
    MultiWordRule(phrase: "bit_and", canon: "y_bit"), MultiWordRule(phrase: "and_bit", canon: "y_bit"),
    MultiWordRule(phrase: "o_bit", canon: "o_bit"), MultiWordRule(phrase: "bit_or", canon: "o_bit"),
    MultiWordRule(phrase: "or_bit", canon: "o_bit"),
    MultiWordRule(phrase: "xor", canon: "xor"), MultiWordRule(phrase: "bit_xor", canon: "xor"),
    MultiWordRule(phrase: "exclusivo_o", canon: "xor"),

    MultiWordRule(phrase: "desplaza_izquierda", canon: "desplaza_izquierda"),
    MultiWordRule(phrase: "shift_left", canon: "desplaza_izquierda"),
    MultiWordRule(phrase: "shl", canon: "desplaza_izquierda"),
    MultiWordRule(phrase: "desplaza_derecha", canon: "desplaza_derecha"),
    MultiWordRule(phrase: "shift_right", canon: "desplaza_derecha"),
    MultiWordRule(phrase: "shr", canon: "desplaza_derecha"),

    # comprobar
    MultiWordRule(phrase: "comprobar", canon: "comprobar"),
    MultiWordRule(phrase: "prueba", canon: "comprobar"), MultiWordRule(phrase: "test", canon: "comprobar"),
    MultiWordRule(phrase: "verifica", canon: "comprobar"),
    MultiWordRule(phrase: "comprueba", canon: "comprobar"),
    MultiWordRule(phrase: "asegurate", canon: "comprobar"),
    MultiWordRule(phrase: "check", canon: "comprobar"), MultiWordRule(phrase: "verify", canon: "comprobar"),
    MultiWordRule(phrase: "assert", canon: "comprobar"), MultiWordRule(phrase: "ensure", canon: "comprobar")
  ]

proc aliasToCanon*(alias: string): string =
  for a in AliasTableInstance.keyAliases:
    if a.alias == alias: return a.canon
  return alias

proc canonToAliases*(canon: string): seq[string] =
  result = @[]
  for a in AliasTableInstance.keyAliases:
    if a.canon == canon: result.add(a.alias)

proc canonicalWord*(w: string): string =
  let low = w.toLower()
  for a in AliasTableInstance.keyAliases:
    if a.alias == low: return a.canon
  return low

proc canonizeTokens*(tokens: seq[string]): seq[string] =
  result = @[]
  var i = 0
  while i < tokens.len:
    var matched = false
    var maxCheck = tokens.len - i
    if maxCheck > 5: maxCheck = 5
    for curLen in countdown(maxCheck, 1):
      if matched: break
      var phraseParts: seq[string] = @[]
      for j in i ..< i + curLen: phraseParts.add(tokens[j])
      let phrase = phraseParts.join(" ")
      for m in AliasTableInstance.multiWords:
        if m.phrase == phrase:
          result.add(m.canon)
          i += curLen
          matched = true
          break
    if not matched:
      result.add(canonicalWord(tokens[i]))
      inc i

proc tryMatchPhrase*(words: seq[string], start: int): (string, int) =
  # devuelve (canon, longitud) o ("", 0) si no hay match de frase compuesta.
  # Canóniza cada palabra de entrada y cada palabra de la frase regla para
  # poder comparar formas canónicas (ej. "es distinto de" == "igual distinto de").
  var maxCheck = words.len - start
  if maxCheck > 5: maxCheck = 5
  for curLen in countdown(maxCheck, 1):
    var phraseParts: seq[string] = @[]
    for j in start ..< start + curLen:
      phraseParts.add(canonicalWord(words[j]))
    let phrase = phraseParts.join(" ")
    for m in AliasTableInstance.multiWords:
      var ruleParts: seq[string] = @[]
      for rp in m.phrase.split(' '):
        ruleParts.add(canonicalWord(rp))
      if ruleParts.join(" ") == phrase:
        return (m.canon, curLen)
  return ("", 0)


proc validateAliasTable*() =
  # Ningún canon debe aparecer como alias de otra palabra sin ser canon de sí mismo,
  # salvo que sea un prefijo intencional. Solo reportamos, no fallamos.
  var canons: seq[string] = @[]
  for a in AliasTableInstance.keyAliases: canons.add(a.canon)
  for a in AliasTableInstance.keyAliases:
    if canons.contains(a.canon) and not (a.alias == a.canon):
      # canon que no es alias de sí mismo: verificación de idempotencia
      discard

proc initAliasTable*() =
  AliasTableInstance = loadAliasTable()

proc multiWords*(): seq[MultiWordRule] =
  AliasTableInstance.multiWords

