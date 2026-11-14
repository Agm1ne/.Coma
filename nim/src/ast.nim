# ast.nim — Definición de Tokens, Nodos AST y Diagnósticos para .Coma
import tables

type
  ErrorKind* = enum
    eError,
    eWarning,
    eNote

  Issue* = object
    line*: int
    col*: int
    code*: string
    level*: ErrorKind
    msg*: string
    hint*: string

  TokenType* = enum
    tokEof,
    tokDot,          # .
    tokColon,        # :
    tokComma,        # ,
    tokIdent,        # Nombre (capitalizado)
    tokKeyword,      # palabra clave canónica en minúsculas
    tokInt,          # 42
    tokFloat,        # 3.14 (parseado de 3,14)
    tokStr,          # "texto"
    tokOp            # +, -, *, /, =, <, > etc.

  Token* = object
    kind*: TokenType
    val*: string
    intVal*: int64
    floatVal*: float64
    line*: int
    col*: int

  DataTypeKind* = enum
    dtUnknown,
    dtVoid,
    dtBool,
    dtInt,       # i8, i16, i32, i64 según sema
    dtFloat,     # double / f32
    dtString,    # i8*
    dtList,      # lista de int
    dtListStr,   # lista de texto
    dtListList,  # lista de listas de int
    dtRecord,    # registro
    dtListRecord # lista de registros
    dtHandle     # asa/opaco (FFI); solo puntero nula o direccion

  NodeKind* = enum
    # Hojas / Literales
    nkInt,
    nkFloat,
    nkStr,
    nkBool,
    nkIdent,
    nkTecla,
    nkMando,
    nkSistema,     # Hora/Fecha/Usuario/Sistema/Version/Directorio (solo lectura)
    nkDelta,
    nkTiempo,

    # Expresiones
    nkBinaryOp,      # +, -, *, /, =, <, >, <=, >=, <>, y, o
    nkUnaryOp,       # menos unario, no
    nkCall,          # Sumar A y B
    nkListAccess,    # Elemento 2 de L, Primero de L, Ultimo de L, Longitud de L
    nkFieldAccess,   # Vida de E / E.Vida
    nkLeeCasilla,    # lee X y Y
    nkAzar,          # azar 6

    # Estructuras literales
    nkListLit,       # lista 1 y 2 y 3 / vacia
    nkRecordLit,     # registro Vida 30 y Ataque 5
    nkListRecordLit, # lista de registros: ... fin

    # Sentencias
    nkAssign,        # X igual expr / Turnos mas 1
    nkFieldAssign,   # Vida de E igual expr / Poner expr en Vida de E
    nkListAssign,    # Elemento 2 de L igual expr
    nkMostrar,       # mostrar expr1 y expr2
    nkPedir,         # pedir X
    nkPisa,          # pisa expr
    nkIf,            # en_caso_de_que cond ... sino ... fin
    nkWhile,         # mientras cond ... fin
    nkTick,          # tick FPS ... fin / tick turbo ... fin
    nkMatch,         # segun expr ... caso ... fin
    nkCaseBranch,    # caso expr1 y expr2: stmts
    nkForEach,       # por_cada X en Lista ... fin
    nkPara,          # para / alto (break)
    nkSigue,         # sigue (continue)
    nkFinLabel,      # fin Etiqueta (multicierre)
    nkDevolver,      # devolver expr
    nkEsperar,       # esperar segs
    nkLimpiar,       # limpiar
    nkLienzo,        # lienzo W y H
    nkMarca,         # marca X y Y con C / muro / moneda / meta
    nkTablero,       # tablero X y Y [y TieneMoneda]
    nkListAdd,       # Agregar X a L
    nkListRemove,    # Quitar X de L
    nkPointerDecl,   # puntero Alias a Original
    nkDireccion,     # direccion de X (direccion/asador de variable)
    nkArchivo,       # abrir/crear/eliminar "ruta" (+cerrar sin nada)
    nkLeerLinea,     # leer Linea (siguiente línea del fichero)
    nkEscribir,      # escribir X (una línea al fichero)
    nkRed,           # conectar/enviar/recibir/desconectar (sesión única TCP)
    nkComprobar,     # comprobar "desc" ... fin (tests automáticos)
    nkExprStmt,      # Expresión suelta como sentencia
    nkVentana,       # ventana abrir/limpiar/color/rectangulo/circulo/linea/rotulo/voltear/cerrar
    nkOcultarConsola, # ocultar consola/cmd (hide console)

    # Declaraciones
    nkFuncDecl,      # funcion Nombre A y B ... fin
    nkRecordBlock,   # registro Nombre: ... fin
    nkTraer,         # traer Guitarra (importa coma/lib/guitarra.coma; solo decls)
    nkBlock,         # lista de sentencias
    nkProgram        # raíz del programa

  Node* = ref object
    kind*: NodeKind
    line*: int
    col*: int
    typ*: DataTypeKind
    intWidth*: int   # 8, 16, 32, 64 si es dtInt
    strVal*: string
    intVal*: int64
    floatVal*: float64
    identName*: string
    # Hijos / campos
    children*: seq[Node]
    left*: Node
    right*: Node
    # Para llamadas / funciones
    funcName*: string
    params*: seq[string]
    paramTyps*: seq[DataTypeKind] # paralelo a params (dtInt por defecto)
    args*: seq[Node]
    # Para registros / listas
    fields*: seq[tuple[name: string, val: Node]]
    recordName*: string
    target*: Node
    # Para control
    cond*: Node
    thenBlock*: Node
    elseBlock*: Node
    label*: string
    # Tipo de retorno declarado (como <tipo>); dtInt por defecto si no se indica
    hasRetTyp*: bool
    # Variables locales del padre capturadas por esta funcion anidada (closure).
    # Paralelo a capturedTyps. Vacío si no es closure o no captura nada.
    capturedVars*: seq[string]
    capturedTyps*: seq[DataTypeKind]
