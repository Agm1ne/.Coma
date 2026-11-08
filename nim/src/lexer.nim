# lexer.nim — Tokenizador y normalizador léxico de .Coma
import strutils, unicode, tables
import ast

const
  # Mapeo de alias a su canónica
  KeywordAliases* = [
    # mostrar
    ("enseñar", "mostrar"), ("exponer", "mostrar"), ("exhibir", "mostrar"),
    ("presentar", "mostrar"), ("desplegar", "mostrar"), ("indicar", "mostrar"),
    ("muestra", "mostrar"), ("enseña", "mostrar"), ("mira", "mostrar"),
    ("canta", "mostrar"), ("suelta", "mostrar"), ("chivate", "mostrar"), ("di", "mostrar"),
    ("pregona", "mostrar"), ("anuncia", "mostrar"), ("declara", "mostrar"),
    ("revela", "mostrar"), ("descubre", "mostrar"), ("grita", "mostrar"),
    ("cuenta", "mostrar"), ("relata", "mostrar"), ("narra", "mostrar"),
    ("detalla", "mostrar"), ("pinta", "mostrar"), ("dibuja", "mostrar"),
    ("escribe", "mostrar"), ("imprime", "mostrar"), ("publica", "mostrar"),
    ("emite", "mostrar"), ("proyecta", "mostrar"), ("refleja", "mostrar"),
    ("escupe", "mostrar"), ("vomita", "mostrar"),
    ("print", "mostrar"), ("display", "mostrar"), ("exhibit", "mostrar"),
    ("present", "mostrar"), ("render", "mostrar"), ("indicate", "mostrar"),
    ("output", "mostrar"), ("show", "mostrar"), ("tell", "mostrar"),
    ("say", "mostrar"), ("spill", "mostrar"), ("shout", "mostrar"),
    ("blurt", "mostrar"), ("dish", "mostrar"), ("write", "mostrar"),
    ("draw", "mostrar"), ("paint", "mostrar"), ("announce", "mostrar"),
    ("proclaim", "mostrar"), ("type", "mostrar"), ("echo", "mostrar"),
    ("log", "mostrar"), ("dump", "mostrar"), ("spew", "mostrar"), ("vomit", "mostrar"),

    # pedir
    ("solicitar", "pedir"), ("preguntar", "pedir"), ("dime", "pedir"),
    ("dame", "pedir"), ("pasa", "pedir"), ("pide", "pedir"),
    ("atiende", "pedir"), ("recibe", "pedir"), ("recoge", "pedir"),
    ("acepta", "pedir"), ("toma", "pedir"), ("agarra", "pedir"),
    ("pilla", "pedir"), ("cuentame", "pedir"),
    ("input", "pedir"), ("ask", "pedir"), ("request", "pedir"),
    ("prompt", "pedir"), ("query", "pedir"), ("gimme", "pedir"),
    ("cough_up", "pedir"), ("get", "pedir"), ("read", "pedir"),
    ("scan", "pedir"), ("fetch", "pedir"), ("collect", "pedir"),
    ("receive", "pedir"), ("accept", "pedir"), ("grab", "pedir"), ("tell_me", "pedir"),

    # en_caso_de_que
    ("si", "en_caso_de_que"), ("en_el_caso_de_que", "en_caso_de_que"),
    ("siempre_que", "en_caso_de_que"), ("dado_que", "en_caso_de_que"),
    ("si_es_que", "en_caso_de_que"), ("cuando", "en_caso_de_que"),
    ("si_acaso", "en_caso_de_que"), ("por_si", "en_caso_de_que"),
    ("por_si_acaso", "en_caso_de_que"), ("puesto_que", "en_caso_de_que"),
    ("ya_que", "en_caso_de_que"), ("a_ver_si", "en_caso_de_que"),
    ("y_si", "en_caso_de_que"),
    ("if", "en_caso_de_que"), ("in_case_that", "en_caso_de_que"),
    ("provided_that", "en_caso_de_que"), ("given_that", "en_caso_de_que"),
    ("when", "en_caso_de_que"), ("suppose", "en_caso_de_que"),
    ("assuming", "en_caso_de_que"), ("lest", "en_caso_de_que"),
    ("on_condition_that", "en_caso_de_que"), ("in_the_event_that", "en_caso_de_que"),
    ("what_if", "en_caso_de_que"),

    # sino
    ("si_no", "sino"), ("de_lo_contrario", "sino"), ("en_caso_contrario", "sino"),
    ("en_otro_caso", "sino"), ("pero", "sino"), ("de_otra_forma", "sino"),
    ("de_otra_manera", "sino"), ("en_su_defecto", "sino"),
    ("else", "sino"), ("if_not", "sino"), ("or_else", "sino"),
    ("instead", "sino"), ("alternatively", "sino"), ("failing_that", "sino"),

    # fin
    ("final", "fin"), ("termina_aqui", "fin"), ("se_acabo", "fin"),
    ("basta", "fin"), ("listo", "fin"), ("ya", "fin"),
    ("terminado", "fin"), ("terminada", "fin"), ("acabado", "fin"),
    ("acabada", "fin"), ("concluido", "fin"), ("cerrado", "fin"),
    ("punto_final", "fin"), ("se_termino", "fin"), ("hasta_aqui", "fin"),
    ("colorin_colorado", "fin"), ("he_dicho", "fin"), ("caso_cerrado", "fin"),
    ("amen", "fin"), ("fin_transmision", "fin"),
    ("end", "fin"), ("finish", "fin"), ("done", "fin"), ("over", "fin"),
    ("enough", "fin"), ("finito", "fin"), ("finished", "fin"),
    ("completed", "fin"), ("concluded", "fin"), ("closed", "fin"),
    ("period", "fin"), ("mic_drop", "fin"), ("case_closed", "fin"),
    ("over_and_out", "fin"), ("end_of_transmission", "fin"),
    ("thats_all", "fin"), ("the_end", "fin"), ("cut", "fin"),

    # mientras
    ("dale", "mientras"), ("en_bucle", "mientras"), ("en_loop", "mientras"),
    ("dale_dale", "mientras"), ("vamos", "mientras"), ("arre", "mientras"),
    ("while", "mientras"), ("whilst", "mientras"), ("as_long_as", "mientras"),
    ("keep_going", "mientras"), ("loop", "mientras"), ("go_go", "mientras"),

    # funcion
    ("procedimiento", "funcion"), ("rutina", "funcion"), ("faena", "funcion"),
    ("chamba", "funcion"), ("laburo", "funcion"), ("curro", "funcion"),
    ("mision", "funcion"), ("encargo", "funcion"), ("cometido", "funcion"),
    ("subrutina", "funcion"), ("proceso", "funcion"),
    ("function", "funcion"), ("procedure", "funcion"), ("routine", "funcion"),
    ("sub", "funcion"), ("method", "funcion"), ("job", "funcion"),
    ("chore", "funcion"), ("gig", "funcion"), ("duty", "funcion"),
    ("errand", "funcion"), ("operation", "funcion"), ("func", "funcion"),
    ("def", "funcion"), ("proc", "funcion"),

    # devolver
    ("retornar", "devolver"), ("entregar", "devolver"), ("regresa", "devolver"),
    ("return", "devolver"), ("give_back", "devolver"), ("hand_back", "devolver"),
    ("yield", "devolver"),

    # conectores lógicos y operadores
    ("e", "y"), ("con", "y"), ("and", "y"), ("with", "y"),
    ("u", "o"), ("o_bien", "o"), ("or", "o"),
    ("nada_de", "no"), ("ni_de_broma", "no"), ("nah", "no"), ("no_way", "no"),
    ("ni_muerto", "no"), ("not", "no"), ("aint", "no"),

    # igual
    ("es", "igual"), ("vale", "igual"), ("equivale_a", "igual"),
    ("son", "igual"),
    ("equal", "igual"), ("equals", "igual"), ("is", "igual"), ("are", "igual"),
    ("comes_to", "igual"), ("es_lo_mismo", "igual"), ("matches", "igual"), ("reads", "igual"),

    # aritmética
    ("más", "mas"), ("suma", "mas"), ("plus", "mas"), ("add", "mas"), ("increased_by", "mas"), ("up_by", "mas"),
    ("resta", "menos"), ("quita", "menos"), ("sustrae", "menos"),
    ("descuenta", "menos"), ("minus", "menos"), ("subtract", "menos"),
    ("deduct", "menos"), ("take_away", "menos"), ("decreased_by", "menos"), ("down_by", "menos"),
    ("multiplica", "por"), ("veces", "por"), ("times", "por"), ("multiply", "por"),
    ("multiplied_by", "por"), ("x", "por"),
    ("divide", "entre"), ("dividido_entre", "entre"), ("dividido_por", "entre"),
    ("reparte", "entre"), ("split", "entre"), ("divided_by", "entre"),

    # comparaciones
    ("mayor_que", "es_mayor_que"), ("mas_grande_que", "es_mayor_que"),
    ("supera_a", "es_mayor_que"), ("gana_a", "es_mayor_que"), ("rebasa", "es_mayor_que"),
    ("is_greater_than", "es_mayor_que"), ("greater_than", "es_mayor_que"),
    ("bigger_than", "es_mayor_que"), ("exceeds", "es_mayor_que"), ("beats", "es_mayor_que"), ("surpasses", "es_mayor_que"),

    ("menor_que", "es_menor_que"), ("mas_chico_que", "es_menor_que"),
    ("mas_pequeno_que", "es_menor_que"), ("no_llega_a", "es_menor_que"),
    ("pierde_contra", "es_menor_que"),
    ("is_less_than", "es_menor_que"), ("less_than", "es_menor_que"),
    ("smaller_than", "es_menor_que"), ("loses_to", "es_menor_que"),

    ("distinto_de", "es_distinto_de"), ("diferente_de", "es_distinto_de"),
    ("is_different", "es_distinto_de"), ("is_not", "es_distinto_de"), ("differ_from", "es_distinto_de"),
    ("empata_con", "es_igual_a"), ("ties_with", "es_igual_a"),
    ("is_equal_to", "es_igual_a"),
    ("is_greater_than", "es_mayor_que"), ("is_less_than", "es_menor_que"),
    ("is_greater_or_equal", "es_mayor_o_igual"),
    ("is_less_or_equal", "es_menor_o_igual"),

    # booleanos
    ("verdadero", "verdad"), ("cierto", "verdad"), ("simon", "verdad"),
    ("sip", "verdad"), ("positivo", "verdad"), ("afirmativo", "verdad"),
    ("correcto", "verdad"), ("correcta", "verdad"), ("exacto", "verdad"), ("exacta", "verdad"),
    ("true", "verdad"), ("right", "verdad"), ("yup", "verdad"), ("yep", "verdad"),
    ("yeah", "verdad"), ("uh_huh", "verdad"), ("correct", "verdad"), ("exact", "verdad"), ("precisely", "verdad"),

    ("mentira", "falso"), ("nel", "falso"), ("negativo", "falso"),
    ("ni_a_palos", "falso"), ("nanai", "falso"),
    ("false", "falso"), ("wrong", "falso"), ("nope", "falso"), ("negative", "falso"), ("no_sir", "falso"),

    # listas
    ("coleccion", "lista"), ("conjunto", "lista"), ("grupo", "lista"),
    ("serie", "lista"), ("sucesion", "lista"), ("tanda", "lista"),
    ("ristra", "lista"), ("retahila", "lista"), ("manojo", "lista"),
    ("monton", "lista"), ("fila", "lista"), ("hilera", "lista"),
    ("list", "lista"), ("collection", "lista"), ("bunch", "lista"),
    ("pile", "lista"), ("array", "lista"), ("set", "lista"),
    ("lineup", "lista"), ("roster", "lista"), ("sequence", "lista"),
    ("succession", "lista"), ("batch", "lista"), ("row", "lista"),
    ("queue", "lista"), ("chain", "lista"),

    ("sin_nada", "vacia"), ("hueca", "vacia"), ("zilch", "vacia"), ("zip", "vacia"), ("nada", "vacia"),
    ("empty", "vacia"), ("blank", "vacia"),

    ("lista_de_texto", "lista_texto"),
    ("lista_de_registros", "lista_de_registros"),
    ("id", "elemento"),
    ("lista_de_listas", "lista_listas"),
    ("lists", "list"),

    ("element", "elemento"),
    ("pieza", "elemento"), ("parte", "elemento"), ("miembro", "elemento"), ("casilla", "elemento"),
    ("trozo", "elemento"), ("pedazo", "elemento"), ("cacho", "elemento"),
    ("fragmento", "elemento"), ("eslabon", "elemento"), ("unidad", "elemento"), ("componente", "elemento"),
    ("item", "elemento"), ("member", "elemento"), ("entry", "elemento"), ("cell", "elemento"),
    ("chunk", "elemento"), ("piece", "elemento"), ("bit", "elemento"), ("fragment", "elemento"),
    ("link", "elemento"), ("unit", "elemento"), ("component", "elemento"), ("thing", "elemento"),

    ("cabeza", "primero"), ("numero_uno", "primero"), ("campeon", "primero"),
    ("ganador", "primero"), ("inicial", "primero"),
    ("first", "primero"), ("head", "primero"), ("number_one", "primero"),
    ("champ", "primero"), ("champion", "primero"), ("winner", "primero"),
    ("initial", "primero"), ("first_off", "primero"),

    ("último", "ultimo"), ("cola", "ultimo"), ("colista", "ultimo"),
    ("farolillo", "ultimo"), ("farolillo_rojo", "ultimo"), ("ultimo_mono", "ultimo"), ("perdedor", "ultimo"),
    ("last", "ultimo"), ("tail", "ultimo"), ("dead_last", "ultimo"), ("loser", "ultimo"), ("caboose", "ultimo"),

    ("largo", "longitud"), ("tamano", "longitud"), ("tamaño", "longitud"),
    ("medida", "longitud"), ("extension", "longitud"),
    ("length", "longitud"), ("size", "longitud"), ("count", "longitud"),
    ("measurement", "longitud"), ("extent", "longitud"), ("span", "longitud"),

    ("añadir", "agregar"), ("anadir", "agregar"), ("meter", "agregar"),
    ("incorpora", "agregar"), ("integra", "agregar"), ("inyecta", "agregar"),
    ("anexa", "agregar"), ("adjunta", "agregar"),
    ("append", "agregar"), ("attach", "agregar"), ("stick_in", "agregar"),
    ("toss_in", "agregar"), ("push", "agregar"), ("inject", "agregar"),
    ("incorporate", "agregar"), ("integrate", "agregar"),

    ("sacar", "quitar"), ("eliminar", "quitar"), ("borrar", "quitar"),
    ("remover", "quitar"), ("extrae", "quitar"), ("arranca", "quitar"),
    ("desecha", "quitar"), ("tira", "quitar"), ("bota", "quitar"), ("expulsa", "quitar"),
    ("remove", "quitar"), ("delete", "quitar"), ("drop", "quitar"),
    ("take_out", "quitar"), ("erase", "quitar"), ("extract", "quitar"),
    ("yank", "quitar"), ("toss", "quitar"), ("chuck", "quitar"), ("ditch", "quitar"), ("discard", "quitar"),

    ("out_of", "de"), ("of", "de"), ("from", "de"),
    ("del", "de"),
    ("to", "a"), ("into", "a"),
    ("al", "a"),
    ("dentro", "en"), ("dentro_de", "en"), ("in", "en"), ("inside", "en"), ("within", "en"),

    # registros y punteros
    ("ficha", "registro"), ("caja", "registro"), ("paquete", "registro"),
    ("cajon", "registro"), ("carpeta", "registro"), ("formulario", "registro"),
    ("record", "registro"), ("card", "registro"), ("file", "registro"),
    ("packet", "registro"), ("struct", "registro"), ("folder", "registro"),
    ("form", "registro"), ("binder", "registro"), ("slip", "registro"),

    ("mete", "poner"), ("coloca", "poner"), ("asigna", "poner"),
    ("fija", "poner"), ("planta", "poner"), ("deposita", "poner"), ("deja", "poner"),
    ("put", "poner"), ("place", "poner"), ("set", "poner"), ("assign", "poner"),
    ("store", "poner"), ("lay", "poner"), ("stick", "poner"), ("leave", "poner"), ("deposit", "poner"),

    ("dedo", "puntero"), ("indicador", "puntero"), ("señalador", "puntero"), ("flecha", "puntero"),
    ("pointer", "puntero"), ("finger", "puntero"), ("indicator", "puntero"), ("cursor", "puntero"),

    # control de bucle
    ("alto", "para"), ("detente", "para"), ("frena", "para"),
    ("frenazo", "para"), ("quieto", "para"), ("para_ya", "para"),
    ("stop", "para"), ("halt", "para"), ("freeze", "para"), ("hold_on", "para"), ("whoa", "para"),

    ("continua", "sigue"), ("continúa", "sigue"), ("adelante", "sigue"),
    ("palante", "sigue"), ("sigue_sigue", "sigue"),
    ("continue", "sigue"), ("carry_on", "sigue"), ("go_on", "sigue"),
    ("onward", "sigue"), ("onwards", "sigue"), ("proceed", "sigue"),

    ("uno_a_uno", "por_cada"),
    ("for_each", "por_cada"), ("for_every", "por_cada"),
    ("one_by_one", "por_cada"), ("foreach", "por_cada"),

    ("as", "como"),
    ("depende", "segun"), ("match", "segun"), ("switch", "segun"), ("depending_on", "segun"),
    ("digamos", "caso"), ("case", "caso"),
    ("resto", "otro"), ("otherwise", "otro"), ("default", "otro"), ("other", "otro"),

    # tiempo, azar, pantalla fija, lienzo
    ("ticks", "tick"), ("fps", "tick"), ("fotogramas", "tick"), ("fotograma", "tick"),
    ("ritmo", "tick"), ("tps", "tick"), ("tiempo", "tick"), ("cuadro", "tick"),
    ("cuadros", "tick"), ("frames", "tick"), ("framerate", "tick"), ("rate", "tick"),

    ("encima", "pisa"), ("overwrite", "pisa"), ("overprint", "pisa"), ("rewrite", "pisa"),
    ("espera", "esperar"), ("aguarda", "esperar"), ("wait", "esperar"),
    ("aleatorio", "azar"), ("random", "azar"),
    ("limpia", "limpiar"), ("despeja", "limpiar"), ("clear", "limpiar"), ("wipe", "limpiar"), ("cls", "limpiar"),
    ("canvas", "lienzo"),
    ("marcar", "marca"), ("sella", "marca"), ("mark", "marca"), ("plot", "marca"), ("stamp", "marca"),
    ("pared", "muro"), ("tapia", "muro"), ("muralla", "muro"), ("tapiar", "muro"), ("amurallar", "muro"), ("wall", "muro"),
    ("coin", "moneda"),
    ("destino", "meta"), ("llegada", "meta"), ("goal", "meta"),
    ("leer", "lee"), ("chusmea", "lee"), ("consulta", "lee"), ("peek", "lee"),
    ("pizarra", "tablero"), ("board", "tablero"),
    # ficheros (sesión única; abrir/crear/escribir/cerrar + eliminar por forma)
    ("abrir", "abrir"), ("abierto", "abrir"), ("open", "abrir"),
    ("abre", "abrir"), ("launch", "abrir"),
    ("cerrar", "cerrar"), ("close", "cerrar"),
    ("cierra", "cerrar"), ("termina", "cerrar"),
    ("crear", "crear"), ("creado", "crear"), ("create", "crear"),
    ("crea", "crear"), ("genera", "crear"), ("fabrica", "crear"),
    ("suprimir", "quitar"), ("suprime", "quitar"), ("destruye", "quitar"),
    ("destroy", "quitar"),
    ("escribir", "escribir"), ("redacta", "escribir"), ("anota", "escribir"),
    ("apunta", "escribir"), ("graba", "escribir"),
    # red (sesión única TCP; conectar/enviar/recibir/desconectar)
    ("conectar", "conectar"), ("conecta", "conectar"), ("conectate", "conectar"),
    ("connect", "conectar"),
    ("enviar", "enviar"), ("envia", "enviar"), ("manda", "enviar"),
    ("send", "enviar"),
    ("recibir", "recibir"), ("recibe", "recibir"),
    ("receive", "recibir"), ("recv", "recibir"),
    ("desconectar", "desconectar"), ("desconecta", "desconectar"), ("cuelga", "desconectar"),
    ("disconnect", "desconectar"),
    # presets del sistema (solo lectura, como Tiempo)
    ("hora", "hora"), ("hour", "hora"),
    ("fecha", "fecha"), ("date", "fecha"),
    ("usuario", "usuario"), ("user", "usuario"), ("username", "usuario"),
    ("sistema", "sistema"), ("system", "sistema"), ("os", "sistema"),
    ("version", "version"),
    ("directorio", "directorio"), ("pwd", "directorio"), ("dir", "directorio"),
    ("cwd", "directorio"),
    ("elemento", "elemento"), ("primero", "primero"), ("ultimo", "ultimo"), ("longitud", "longitud"),
    ("lista", "lista"), ("registro", "registro"), ("puntero", "puntero"), ("esperar", "esperar"),
    ("azar", "azar"), ("limpiar", "limpiar"), ("lienzo", "lienzo"), ("marca", "marca"),
    ("tablero", "tablero"), ("muro", "muro"), ("moneda", "moneda"), ("meta", "meta"),
    ("poner", "poner"), ("mostrar", "mostrar"), ("pedir", "pedir"), ("fin", "fin"),
    ("mientras", "mientras"), ("funcion", "funcion"), ("devolver", "devolver"),
    ("agregar", "agregar"), ("quitar", "quitar"),
    # canonicas reservadas (lectura: Tecla/Tiempo/Delta/Lee/Tick/Segun/...)
    ("tecla", "tecla"), ("key", "tecla"), ("pulsacion", "tecla"), ("teclazo", "tecla"),
    ("keypress", "tecla"), ("tequita", "tecla"), ("boton", "tecla"), ("button", "tecla"),
    ("tecleo", "tecla"), ("pulsada", "tecla"),
    ("tiempo", "tiempo"), ("time", "tiempo"), ("reloj", "tiempo"), ("cronometro", "tiempo"),
    ("clock", "tiempo"), ("elapsed", "tiempo"), ("transcurrido", "tiempo"),
    ("delta", "delta"), ("segundos", "delta"), ("segundo", "delta"),
    ("dt", "delta"), ("paso", "delta"), ("step", "delta"), ("diferencial", "delta"),
    ("tick", "tick"), ("turbo", "turbo"), ("segun", "segun"), ("caso", "caso"),
    ("otro", "otro"),     ("como", "como"), ("por_cada", "por_cada"),
    ("sino", "sino"), ("en_caso_de_que", "en_caso_de_que"),
    ("y", "y"), ("o", "o"), ("no", "no"), ("and", "y"),
    ("igual", "igual"), ("mas", "mas"), ("menos", "menos"), ("por", "por"), ("entre", "entre"),
    ("is", "igual"), ("is_equal_to", "es_igual_a"), ("is_equal", "es_igual_a"),
    ("es_igual_a", "es_igual_a"),
    ("es_equivalente_a", "es_equivalente_a"), ("equivalente_a", "es_equivalente_a"),
    ("is_equivalent_to", "es_equivalente_a"), ("equivalent_to", "es_equivalente_a"), ("es_mayor_que", "es_mayor_que"), ("es_menor_que", "es_menor_que"),
    ("es_distinto_de", "es_distinto_de"), ("es_mayor_o_igual", "es_mayor_o_igual"),
    ("es_menor_o_igual", "es_menor_o_igual"),
    ("verdad", "verdad"), ("falso", "falso"), ("null", "nula"), ("none", "nula"), ("nil", "nula"),
    ("de", "de"), ("a", "a"), ("en", "en"),
    ("lee", "lee"), ("pisa", "pisa"), ("vacia", "vacia"),
    ("para", "para"), ("sigue", "sigue"),
    ("conectar", "conectar"), ("enviar", "enviar"),
    ("recibir", "recibir"), ("desconectar", "desconectar"),
    # mando: pad, guitarra GH, palanca, volante (10 por significado)
    ("mando", "mando"), ("pad", "mando"), ("gamepad", "mando"),
    ("joystick", "mando"), ("palanca", "mando"), ("guitarra", "mando"),
    ("control", "mando"), ("controller", "mando"), ("arcade", "mando"),
    ("volante", "mando"),
    # sobrecarga extra: mas/menos/por/entre/devolver/distinto (10+ por significado)
    ("ponle", "mas"), ("sumale", "mas"), ("agregale", "mas"), ("cargale", "mas"),
    ("add_up", "mas"), ("plus_up", "mas"),
    ("replica", "por"), ("duplica", "por"), ("triplica", "por"),
    ("triple", "por"), ("fold", "por"),
    ("fracciona", "entre"), ("corta", "entre"),
    ("share", "entre"), ("cut_up", "entre"),
    ("flaquea_ante", "es_menor_que"), ("underperforms", "es_menor_que"),
    ("difiere_de", "es_distinto_de"), ("no_iguala", "es_distinto_de"),
    ("differs", "es_distinto_de"), ("mismatches", "es_distinto_de"),
    ("cambia_de", "es_distinto_de"), ("varia_de", "es_distinto_de"),
    ("devuelve", "devolver"), ("retorna", "devolver"), ("remite", "devolver"),
    ("gives_back", "devolver"), ("hands_over", "devolver")
  ]

  # Frases compuestas a unir automáticamente
  MultiWordRules* = [
    ("en el caso de que", "en_caso_de_que"),
    ("en caso de que", "en_caso_de_que"),
    ("in case that", "en_caso_de_que"),
    ("on condition that", "en_caso_de_que"),
    ("in the event that", "en_caso_de_que"),
    ("por si acaso", "en_caso_de_que"),
    ("a ver si", "en_caso_de_que"),
    ("de lo contrario", "sino"),
    ("en caso contrario", "sino"),
    ("en otro caso", "sino"),
    ("de otra forma", "sino"),
    ("de otra manera", "sino"),
    ("en su defecto", "sino"),
    ("or else", "sino"),
    ("termina aqui", "fin"),
    ("termina aquí", "fin"),
    ("se acabo", "fin"),
    ("se acabó", "fin"),
    ("se termino", "fin"),
    ("se terminó", "fin"),
    ("punto final", "fin"),
    ("colorin colorado", "fin"),
    ("caso cerrado", "fin"),
    ("case closed", "fin"),
    ("over and out", "fin"),
    ("end of transmission", "fin"),
    ("thats all", "fin"),
    ("the end", "fin"),
    ("en bucle", "mientras"),
    ("en loop", "mientras"),
    ("dale dale", "mientras"),
    ("as long as", "mientras"),
    ("keep going", "mientras"),
    ("go go", "mientras"),
    ("es igual a", "igual"),
    ("is equal to", "igual"),
    ("is equal", "igual"),
    ("are equal to", "igual"),
    ("are equal", "igual"),
    ("igual a", "igual"),
    ("es igual", "igual"),
    ("son igual", "igual"),
    ("son iguales a", "igual"),
    ("es mayor que", "es_mayor_que"),
    ("are greater than", "es_mayor_que"),
    ("is greater than", "es_mayor_que"),
    ("mayor que", "es_mayor_que"),
    ("greater than", "es_mayor_que"),
    ("mas grande que", "es_mayor_que"),
    ("más grande que", "es_mayor_que"),
    ("bigger than", "es_mayor_que"),
    ("es menor que", "es_menor_que"),
    ("are less than", "es_menor_que"),
    ("is less than", "es_menor_que"),
    ("menor que", "es_menor_que"),
    ("less than", "es_menor_que"),
    ("mas chico que", "es_menor_que"),
    ("más chico que", "es_menor_que"),
    ("mas pequeno que", "es_menor_que"),
    ("más pequeño que", "es_menor_que"),
    ("smaller than", "es_menor_que"),
    ("es distinto de", "es_distinto_de"),
    ("distinto de", "es_distinto_de"),
    ("diferente de", "es_distinto_de"),
    ("is different", "es_distinto_de"),
    ("different from", "es_distinto_de"),
    ("different to", "es_distinto_de"),
    ("es mayor", "es_mayor_que"),
    ("es menor", "es_menor_que"),
    ("no es", "es_distinto_de"),
    ("is different from", "es_distinto_de"),
    ("are different from", "es_distinto_de"),
    ("are equivalent to", "es_equivalente_a"),
    ("es mayor o igual", "es_mayor_o_igual"),
    ("es menor o igual", "es_menor_o_igual"),
    ("mayor o igual", "es_mayor_o_igual"),
    ("menor o igual", "es_menor_o_igual"),
    ("es mayor o igual a", "es_mayor_o_igual"),
    ("es menor o igual a", "es_menor_o_igual"),
    ("mayor o igual a", "es_mayor_o_igual"),
    ("menor o igual a", "es_menor_o_igual"),
    ("es mayor a", "es_mayor_que"),
    ("es menor a", "es_menor_que"),
    ("mayor a", "es_mayor_que"),
    ("menor a", "es_menor_que"),
    ("es mayor de", "es_mayor_que"),
    ("es menor de", "es_menor_que"),
    ("mayor de", "es_mayor_que"),
    ("menor de", "es_menor_que"),
    ("es distinto a", "es_distinto_de"),
    ("es diferente a", "es_distinto_de"),
    ("distinto a", "es_distinto_de"),
    ("diferente a", "es_distinto_de"),
    ("es distinto que", "es_distinto_de"),
    ("es diferente que", "es_distinto_de"),
    ("distinto que", "es_distinto_de"),
    ("diferente que", "es_distinto_de"),
    ("es mayor que", "es_mayor_que"),
    ("es menor que", "es_menor_que"),
    ("equivalente a", "es_equivalente_a"),
    ("es equivalente a", "es_equivalente_a"),
    ("equivalent to", "es_equivalente_a"),
    ("is equivalent to", "es_equivalente_a"),
    ("por cada", "por_cada"),
    ("for each", "por_cada"),
    ("for every", "por_cada"),
    ("one by one", "por_cada"),
    ("depending on", "segun"),
    ("sin nada", "vacia"),
    ("lista de registros", "lista_de_registros"),
    ("list of records", "lista_de_registros"),
    ("lista de texto", "lista_texto"),
    ("list of text", "lista_texto"),
    ("lista de listas", "lista_listas"),
    ("lista de lista", "lista_listas"),
    ("list of lists", "lista_listas"),
    ("give back", "devolver"),
    ("hand back", "devolver"),
    ("cough up", "pedir"),
    ("take away", "menos"),
    ("stick in", "agregar"),
    ("toss in", "agregar"),
    ("take out", "quitar"),
    ("carry on", "sigue"),
    ("go on", "sigue"),
    ("hold on", "para"),
    ("para ya", "para"),
    ("sigue sigue", "sigue"),
    ("y_bit", "y_bit"), ("bit_and", "y_bit"), ("and_bit", "y_bit"),
    ("o_bit", "o_bit"), ("bit_or", "o_bit"), ("or_bit", "o_bit"),
    ("xor", "xor"), ("bit_xor", "xor"), ("exclusivo_o", "xor"),
    ("desplaza_izquierda", "desplaza_izquierda"), ("shift_left", "desplaza_izquierda"), ("shl", "desplaza_izquierda"),
    ("desplaza_derecha", "desplaza_derecha"), ("shift_right", "desplaza_derecha"), ("shr", "desplaza_derecha"),
    ("comprobar", "comprobar"), ("prueba", "comprobar"), ("test", "comprobar"),
    ("verifica", "comprobar"), ("comprueba", "comprobar"), ("asegurate", "comprobar"),
    ("check", "comprobar"), ("verify", "comprobar"), ("assert", "comprobar"), ("ensure", "comprobar")
  ]

var AliasTable: Table[string, string]

proc initAliases() =
  if AliasTable.len > 0: return
  AliasTable = initTable[string, string]()
  for (aliasWord, canon) in KeywordAliases:
    AliasTable[aliasWord] = canon

initAliases()

proc canonizeWord*(w: string): string =
  let low = w.toLower()
  if AliasTable.hasKey(low):
    return AliasTable[low]
  return low

type
  Lexer* = object
    src*: string
    pos*: int
    line*: int
    col*: int
    issues*: seq[Issue]

proc newLexer*(src: string): Lexer =
  result.src = src
  result.pos = 0
  result.line = 1
  result.col = 1
  result.issues = @[]

proc peek(lex: Lexer, offset = 0): char =
  let idx = lex.pos + offset
  if idx < lex.src.len:
    return lex.src[idx]
  return '\0'

proc advance(lex: var Lexer): char =
  if lex.pos < lex.src.len:
    result = lex.src[lex.pos]
    inc lex.pos
    if result == '\n':
      inc lex.line
      lex.col = 1
    else:
      inc lex.col
  else:
    result = '\0'

# Tokeniza un archivo completo en tokens primarios
proc rawTokenize*(lex: var Lexer): seq[Token] =
  var tokens: seq[Token] = @[]

  while lex.pos < lex.src.len:
    let ch = lex.peek()

    # Espacios en blanco (salvo saltos que cuentan columnas/líneas)
    if ch in {' ', '\t', '\r', '\n'}:
      discard lex.advance()
      continue

    # Comentarios simétricos | ... |
    if ch == '|':
      let startLine = lex.line
      let startCol = lex.col
      discard lex.advance() # consumir '|'
      while lex.pos < lex.src.len and lex.peek() != '|' and lex.peek() != '\n':
        discard lex.advance()
      if lex.peek() == '|':
        discard lex.advance()
      else:
        # | sin cerrar hasta fin de línea: aviso E006
        lex.issues.add(Issue(line: startLine, col: startCol, code: "E006", level: eWarning,
                             msg: "comentario | no cerrado en la misma linea", hint: "cierra con |"))
      continue

    # Terminador punto '.' y dos puntos ':'
    if ch == '.':
      let line = lex.line
      let col = lex.col
      discard lex.advance()
      tokens.add(Token(kind: tokDot, val: ".", line: line, col: col))
      continue

    if ch == ':':
      let line = lex.line
      let col = lex.col
      discard lex.advance()
      tokens.add(Token(kind: tokColon, val: ":", line: line, col: col))
      continue

    # Cadenas "..." con escape de comillas dobles ""
    if ch == '"':
      let line = lex.line
      let col = lex.col
      discard lex.advance()
      var s = ""
      while lex.pos < lex.src.len:
        if lex.peek() == '"':
          if lex.peek(1) == '"':
            s.add('"')
            discard lex.advance()
            discard lex.advance()
          else:
            discard lex.advance()
            break
        else:
          s.add(lex.advance())
      tokens.add(Token(kind: tokStr, val: s, line: line, col: col))
      continue

    # Hexadecimales: 0xFF, 0xCAFE_BABE, -0x10
    let isHexNeg = ch == '-' and lex.peek() == '0' and lex.peek(1) in {'x', 'X'}
    let isHexPos = ch == '0' and lex.peek(1) in {'x', 'X'}
    if isHexPos or isHexNeg:
      let line = lex.line
      let col = lex.col
      var hexStr = ""
      if isHexNeg:
        hexStr.add(lex.advance()) # '-'
      hexStr.add(lex.advance()) # '0'
      hexStr.add(lex.advance()) # 'x' or 'X'
      while lex.peek() in {'0'..'9', 'a'..'f', 'A'..'F', '_'}:
        let c = lex.advance()
        if c != '_':
          hexStr.add(c)
      try:
        let cleanHex = hexStr.replace("-", "").replace("0x", "").replace("0X", "")
        let iVal = parseHexInt(cleanHex)
        let finalVal = if hexStr.startsWith("-"): -int64(iVal) else: int64(iVal)
        tokens.add(Token(kind: tokInt, val: hexStr, intVal: finalVal, line: line, col: col))
      except ValueError:
        lex.issues.add(Issue(line: line, col: col, code: "E001", level: eError,
                             msg: "literal hexadecimal mal formado", hint: "usa formato 0xFF"))
        tokens.add(Token(kind: tokInt, val: hexStr, intVal: 0, line: line, col: col))
      continue

    # Números: enteros (25, 25000) o decimales con coma (3,14) o negativos (-3,14 / -5)
    let isNegPrefix = tokens.len == 0 or tokens[^1].kind in {tokOp, tokDot, tokColon, tokKeyword} or
                      tokens[^1].val in ["igual", "mas", "menos", "por", "entre", "es"]
    if ch in {'0'..'9'} or (ch == '-' and lex.peek(1) in {'0'..'9'} and isNegPrefix):
      let line = lex.line
      let col = lex.col
      var numStr = ""
      if ch == '-':
        numStr.add(lex.advance())
      while lex.peek() in {'0'..'9'}:
        numStr.add(lex.advance())

      # Comprobar si sigue una coma decimal: '3,14'
      if lex.peek() == ',' and lex.peek(1) in {'0'..'9'}:
        numStr.add('.') # convertir internamente coma a punto para flotante
        discard lex.advance() # consumir ','
        while lex.peek() in {'0'..'9'}:
          numStr.add(lex.advance())
        let fVal = parseFloat(numStr)
        tokens.add(Token(kind: tokFloat, val: numStr, floatVal: fVal, line: line, col: col))
      elif lex.peek() == ',' and lex.peek(1) notin {'0'..'9'}:
        lex.issues.add(Issue(line: line, col: col, code: "E001", level: eError,
                             msg: "coma decimal solitaria sin digitos posteriores", hint: "escribe 3,0 o 0,5"))
        discard lex.advance()
      else:
        let iVal = parseBiggestInt(numStr)
        tokens.add(Token(kind: tokInt, val: numStr, intVal: iVal, line: line, col: col))
      continue

    # Operadores simbólicos extendidos (&, |, ^, <<, >>)
    if ch in {'&', '|', '^'}:
      let line = lex.line
      let col = lex.col
      let op = lex.advance()
      let mapped = case op
        of '&': "y_bit"
        of '|': "o_bit"
        of '^': "xor"
        else: $op
      tokens.add(Token(kind: tokKeyword, val: mapped, line: line, col: col))
      continue

    if ch == '<' and lex.peek(1) == '<':
      let line = lex.line
      let col = lex.col
      discard lex.advance()
      discard lex.advance()
      tokens.add(Token(kind: tokKeyword, val: "desplaza_izquierda", line: line, col: col))
      continue

    if ch == '>' and lex.peek(1) == '>':
      let line = lex.line
      let col = lex.col
      discard lex.advance()
      discard lex.advance()
      tokens.add(Token(kind: tokKeyword, val: "desplaza_derecha", line: line, col: col))
      continue

    # Operadores simbólicos
    if ch in {'=', '+', '-', '*', '/'}:
      let line = lex.line
      let col = lex.col
      let op = lex.advance()
      let mapped = case op
        of '=': "igual"
        of '+': "mas"
        of '-': "menos"
        of '*': "por"
        of '/': "entre"
        else: $op
      tokens.add(Token(kind: tokKeyword, val: mapped, line: line, col: col))
      continue

    # Palabras / Identificadores (soporte completo de Unicode NFC / ñ / tildes)
    if ch.isAlphaNumeric or ord(ch) >= 128 or ch == '_':
      let line = lex.line
      let col = lex.col
      var w = ""
      while lex.pos < lex.src.len:
        let c = lex.peek()
        if c.isAlphaNumeric or ord(c) >= 128 or c == '_':
          w.add(lex.advance())
        else:
          break

      # Si inicia en Mayúscula: es Identificador (variable/función) a menos que sea
      # LITERALMENTE un comando (ES o EN vistos en fuentes). OJO: se compara `low`,
      # NO la canónica: Manojo/Caja/Fila son VARIABLES aunque manojo→lista, caja→registro.
      let runes = toRunes(w)
      let low = w.toLower()
      if runes.len > 0 and runes[0].isUpper():
        if low in ["elemento", "primero", "ultimo", "longitud", "lista", "registro",
                   "agregar", "quitar", "poner", "puntero", "esperar", "azar",
                   "limpiar", "lienzo", "marca", "tablero", "muro", "moneda", "meta",
                   "tecla", "key", "tiempo", "time", "delta", "lee", "peek", "pisa",
                   "mostrar", "print", "pedir", "input", "funcion", "function",
                   "devolver", "return", "mientras", "while",
                   "para", "stop", "sigue", "continue",
                   "element", "first", "last", "length", "list", "empty",
                   "remove", "delete", "append", "put",
                   "mando",
                    "abrir", "open", "cerrar", "close", "crear", "create",
                    "conectar", "connect", "enviar", "send", "recibir", "receive",
                    "desconectar", "disconnect",
                   "eliminar", "suprimir", "escribir",
                   "hora", "fecha", "usuario", "sistema", "version",
                   "directorio"]:
          tokens.add(Token(kind: tokKeyword, val: canonizeWord(w), line: line, col: col))
        else:
          tokens.add(Token(kind: tokIdent, val: w, line: line, col: col))
      else:
        # Minúscula: siempre keyword (normalizado con alias)
        let canon = canonizeWord(w)
        tokens.add(Token(kind: tokKeyword, val: canon, line: line, col: col))
      continue

    # Si es cualquier otro caracter no reconocido
    let line = lex.line
    let col = lex.col
    let badChar = lex.advance()
    lex.issues.add(Issue(line: line, col: col, code: "E001", level: eError,
                         msg: "caracter inesperado: " & badChar, hint: "revisa la sintaxis"))

  tokens.add(Token(kind: tokEof, val: "", line: lex.line, col: lex.col))
  return tokens

# Segunda pasada del lexer: Unión inteligente de frases compuestas (MultiWordRules)
proc mergeCompoundPhrases*(tokens: seq[Token]): seq[Token] =
  var resultSeq: seq[Token] = @[]
  var i = 0
  var maxLen = 0
  for (rp, _) in MultiWordRules:
    let l = rp.split(' ').len
    if l > maxLen: maxLen = l

  while i < tokens.len:
    if tokens[i].kind == tokEof:
      resultSeq.add(tokens[i])
      break

    # Intentar hacer match de frases compuestas desde la más larga
    var matched = false
    for curLen in countdown(maxLen, 1):
      if matched: break
      for (rulePhrase, canon) in MultiWordRules:
        let parts = rulePhrase.split(' ')
        if parts.len != curLen: continue
        if i + parts.len <= tokens.len:
          var allMatch = true
          for pIdx, part in parts:
            let tok = tokens[i + pIdx]
            let expected = canonizeWord(part)
            if tok.kind != tokKeyword or (tok.val != expected and tok.val != part.toLower()):
              allMatch = false
              break
          if allMatch:
            # Match encontrado: fusionar en un solo token
            let firstTok = tokens[i]
            resultSeq.add(Token(kind: tokKeyword, val: canon, line: firstTok.line, col: firstTok.col))
            i += parts.len
            matched = true
            break
    if not matched:
      resultSeq.add(tokens[i])
      inc i

  return resultSeq

proc tokenize*(src: string, issues: var seq[Issue]): seq[Token] =
  var cleanSrc = src.replace("“", "\"").replace("”", "\"").replace("‘", "'").replace("’", "'")
  # Quitar BOM UTF-8 inicial si existe (EF BB BF)
  if cleanSrc.len >= 3 and cleanSrc[0] == '\xEF' and cleanSrc[1] == '\xBB' and cleanSrc[2] == '\xBF':
    cleanSrc = cleanSrc[3 .. ^1]
  var lex = newLexer(cleanSrc)
  let raw = lex.rawTokenize()
  issues.add(lex.issues)
  return mergeCompoundPhrases(raw)
