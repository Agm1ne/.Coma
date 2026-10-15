// coma-ide.cs — GUI básica de .Coma en un solo .exe (WinForms, sin dependencias).
// Editor + LSP en tiempo real (diagnósticos de verdad vía coma.exe --ir) +
// recuadro del diccionario ES/EN con buscador + botón de guardar diario.
// Compilar: csc /target:winexe /out:coma-ide.exe ide.cs (ver build.bat)
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using System.Windows.Forms;

static class DictData
{
    // canon, alias ES, alias EN
    public static readonly string[][] Entradas = new string[][]
    {
        new string[] {"mostrar", "enseñar, exponer, muestra, mira, di", "print, display, show, tell, say"},
        new string[] {"pedir", "solicitar, preguntar, dime, dame", "input, ask, request, prompt"},
        new string[] {"en_caso_de_que", "si, cuando, siempre_que, dado_que", "if, when, provided_that"},
        new string[] {"sino", "si_no, pero, de_lo_contrario", "else, if_not, or_else"},
        new string[] {"fin", "final, basta, listo, ya", "end, finish, done, over"},
        new string[] {"mientras", "dale", "while, whilst, as_long_as"},
        new string[] {"funcion", "procedimiento, rutina", "function, procedure, sub"},
        new string[] {"devolver", "retornar, entregar", "return, give_back, yield"},
        new string[] {"y", "e, con", "and, with"},
        new string[] {"o", "u", "or"},
        new string[] {"no", "", "not, aint"},
        new string[] {"igual", "es, son, vale", "equal, is, are"},
        new string[] {"mas", "suma", "plus, add"},
        new string[] {"menos", "resta, quita", "minus, subtract"},
        new string[] {"por", "multiplica, veces", "times, multiply"},
        new string[] {"entre", "divide", "divide, divided_by"},
        new string[] {"es_mayor_que", "mayor_que, mayor_a, supera_a", "is_greater_than, greater_than"},
        new string[] {"es_menor_que", "menor_que, menor_a, mas_chico_que", "is_less_than, less_than"},
        new string[] {"es_distinto_de", "distinto_de, distinto_a, diferente_de", "is_different, differ_from, different_to"},
        new string[] {"es_mayor_o_igual", "mayor_o_igual_a", "is_greater_or_equal"},
        new string[] {"es_menor_o_igual", "menor_o_igual_a", "is_less_or_equal"},
        new string[] {"es_equivalente_a", "equivalente_a", "is_equivalent_to, equivalent_to"},
        new string[] {"verdad", "verdadero, cierto, simon", "true, right, yup"},
        new string[] {"falso", "mentira, nel", "false, wrong, nope"},
        new string[] {"lista", "coleccion, grupo", "list, array, set"},
        new string[] {"vacia", "sin_nada", "empty, blank"},
        new string[] {"elemento", "pieza, casilla", "element, item, cell"},
        new string[] {"primero", "cabeza", "first, head"},
        new string[] {"ultimo", "cola", "last, tail"},
        new string[] {"longitud", "largo, tamano", "length, size, count"},
        new string[] {"agregar", "añadir, meter", "add, append, push"},
        new string[] {"quitar", "sacar, eliminar, borrar", "remove, delete, drop"},
        new string[] {"de", "", "of, from"},
        new string[] {"a", "", "to"},
        new string[] {"en", "dentro", "in, inside"},
        new string[] {"registro", "ficha, caja", "record, struct"},
        new string[] {"poner", "mete, coloca", "put, place, set"},
        new string[] {"puntero", "dedo", "pointer, finger"},
        new string[] {"para", "alto, detente", "stop, halt"},
        new string[] {"sigue", "continua", "continue, carry_on"},
        new string[] {"por_cada", "cada", "for_each, each"},
        new string[] {"como", "", "as"},
        new string[] {"segun", "depende", "match, switch"},
        new string[] {"caso", "digamos", "case"},
        new string[] {"otro", "resto", "other, otherwise, default"},
        new string[] {"tick", "ritmo, fotogramas", "fps, frames"},
        new string[] {"esperar", "espera, aguarda", "wait"},
        new string[] {"azar", "aleatorio", "random"},
        new string[] {"limpiar", "limpia, despeja", "clear, wipe, cls"},
        new string[] {"lienzo", "", "canvas"},
        new string[] {"marca", "marcar, sella", "mark, plot, stamp"},
        new string[] {"tablero", "pizarra", "board"},
        new string[] {"pisa", "encima", "overwrite, rewrite"},
        new string[] {"lee", "leer, chusmea", "peek"},
        new string[] {"comprobar", "prueba, verifica", "check, test, assert"},
        new string[] {"conectar", "conecta", "connect"},
        new string[] {"enviar", "envia, manda", "send"},
        new string[] {"recibir", "recibe", "receive, recv"},
        new string[] {"desconectar", "desconecta, cuelga", "disconnect"},
        new string[] {"y_bit", "", "bit_and, and_bit"},
        new string[] {"o_bit", "", "bit_or, or_bit"},
        new string[] {"xor", "exclusivo_o", "bit_xor"},
        new string[] {"desplaza_izquierda", "", "shift_left, shl"},
        new string[] {"desplaza_derecha", "", "shift_right, shr"},
        new string[] {"tecla", "", "key"},
        new string[] {"tiempo", "", "time"},
        new string[] {"delta", "segundo", "dt, step"}
    };
}

class Problema
{
    public int Linea;
    public int Col;
    public string Codigo;
    public string Nivel;
    public string Msg;
    public override string ToString()
    {
        return string.Format("linea {0} [{1}] {2}", Linea, Codigo, Msg);
    }
}

class Sugerencia
{
    public string Palabra;
    public string Canon;
    public int Puntos;
    public string Texto
    {
        get
        {
            if (Palabra == Canon) return Palabra;
            return Palabra + "  →  " + Canon;
        }
    }
}

static class MotorSugerir
{
    public static int Distancia(string a, string b)
    {
        a = a.ToLowerInvariant();
        b = b.ToLowerInvariant();
        int n = a.Length, m = b.Length;
        if (n == 0) return m;
        if (m == 0) return n;
        int[,] d = new int[n + 1, m + 1];
        for (int i = 0; i <= n; i++) d[i, 0] = i;
        for (int j = 0; j <= m; j++) d[0, j] = j;
        for (int i = 1; i <= n; i++)
            for (int j = 1; j <= m; j++)
            {
                int costo = (a[i - 1] == b[j - 1]) ? 0 : 1;
                int v = d[i - 1, j] + 1;
                int v2 = d[i, j - 1] + 1;
                if (v2 < v) v = v2;
                int v3 = d[i - 1, j - 1] + costo;
                if (v3 < v) v = v3;
                d[i, j] = v;
            }
        return d[n, m];
    }

    // Las que más se parecen primero: prefijo > contenido > distancia de edición.
    public static List<Sugerencia> Sugerir(string pedazo, bool en)
    {
        var res = new List<Sugerencia>();
        if (pedazo == null || pedazo.Length < 1) return res;
        string q = pedazo.ToLowerInvariant();
        foreach (string[] e in DictData.Entradas)
        {
            string canon = e[0];
            string[] aliases = (en ? e[2] : e[1]).Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries);
            var candidatas = new List<string>();
            candidatas.Add(canon);
            foreach (string a in aliases)
            {
                string t = a.Trim();
                if (t != "" && !candidatas.Contains(t)) candidatas.Add(t);
            }
            foreach (string c in candidatas)
            {
                string cl = c.ToLowerInvariant();
                int puntos = -1;
                if (cl.StartsWith(q)) puntos = 0;
                else if (cl.IndexOf(q) >= 0) puntos = 1;
                else if (cl.Length >= 2)
                {
                    int d = Distancia(q, cl);
                    int tope = Math.Max(2, cl.Length / 3);
                    if (d <= tope) puntos = 2 + d;
                }
                if (puntos >= 0)
                {
                    var s = new Sugerencia();
                    s.Palabra = c;
                    s.Canon = canon;
                    s.Puntos = puntos * 100 + c.Length;
                    res.Add(s);
                }
            }
        }
        res.Sort(delegate (Sugerencia x, Sugerencia y) { return x.Puntos.CompareTo(y.Puntos); });
        if (res.Count > 8)
        {
            var recorte = new List<Sugerencia>();
            for (int i = 0; i < 8; i++) recorte.Add(res[i]);
            res = recorte;
        }
        return res;
    }
}

class IdeForm : Form
{
    RichTextBox ed;
    ListBox lstProb;
    ListBox lstDict;
    TextBox txtBuscar;
    ComboBox cmbLang;
    ComboBox cmbEx;
    RichTextBox txtOut;
    ToolStripStatusLabel st;
    Button bRun;
    Timer debounce;
    string comaExe = "";
    string tmpDir = "";
    List<Problema> actual = new List<Problema>();
    bool corriendo = false;
    Panel popPanel;
    Label lblPop;
    List<Sugerencia> sugs = new List<Sugerencia>();
    int popIni = 0;
    bool headless = false;

    static readonly Regex RxIssue = new Regex(
        @"^linea (\d+):(\d+) \[([A-Z]\d+) (\w+)\]: (.*)$",
        RegexOptions.Compiled);

    public IdeForm()
    {
        Text = ".Coma IDE v0.5 — todo en un .exe";
        Size = new Size(1100, 700);
        BackColor = Color.FromArgb(30, 30, 30);
        ForeColor = Color.FromArgb(212, 212, 212);

        comaExe = BuscarComa();
        tmpDir = Path.Combine(Path.GetTempPath(), "coma_ide");
        Directory.CreateDirectory(tmpDir);

        var raiz = new TableLayoutPanel();
        raiz.Dock = DockStyle.Fill;
        raiz.RowCount = 3;
        raiz.ColumnCount = 1;
        raiz.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        raiz.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        raiz.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        Controls.Add(raiz);

        var barra = new FlowLayoutPanel();
        barra.AutoSize = true;
        barra.Dock = DockStyle.Fill;
        barra.BackColor = Color.FromArgb(45, 45, 45);
        raiz.Controls.Add(barra, 0, 0);

        bRun = NuevoBoton("Ejecutar");
        bRun.Click += delegate { Ejecutar(); ed.Focus(); };
        barra.Controls.Add(bRun);
        var bClear = NuevoBoton("Limpiar");
        bClear.Click += delegate { ed.Clear(); txtOut.Clear(); Actualizar(null); PonEstado("Limpio."); ed.Focus(); };
        barra.Controls.Add(bClear);
        var bLog = NuevoBoton("Guardar diario");
        bLog.Click += delegate { GuardarDiario(); ed.Focus(); };
        barra.Controls.Add(bLog);

        cmbEx = new ComboBox();
        cmbEx.DropDownStyle = ComboBoxStyle.DropDownList;
        cmbEx.BackColor = Color.FromArgb(60, 60, 60);
        cmbEx.ForeColor = Color.White;
        cmbEx.Items.Add("Ejemplos…");
        cmbEx.Items.Add("Oleada (ES)");
        cmbEx.Items.Add("Wave (EN)");
        cmbEx.Items.Add("Humano (ES)");
        cmbEx.SelectedIndex = 0;
        cmbEx.SelectedIndexChanged += delegate { CargarEjemplo(); };
        barra.Controls.Add(cmbEx);

        cmbLang = new ComboBox();
        cmbLang.DropDownStyle = ComboBoxStyle.DropDownList;
        cmbLang.BackColor = Color.FromArgb(60, 60, 60);
        cmbLang.ForeColor = Color.White;
        cmbLang.Items.Add("Diccionario: ES");
        cmbLang.Items.Add("Dictionary: EN");
        cmbLang.SelectedIndex = 0;
        cmbLang.SelectedIndexChanged += delegate { PintarDict(); };
        barra.Controls.Add(cmbLang);

        var split = new SplitContainer();
        split.Dock = DockStyle.Fill;
        split.SplitterDistance = 700;
        split.BackColor = Color.FromArgb(60, 60, 60);
        raiz.Controls.Add(split, 0, 1);

        ed = new RichTextBox();
        ed.Dock = DockStyle.Fill;
        ed.Font = new Font("Consolas", 12);
        ed.BackColor = Color.FromArgb(30, 30, 30);
        ed.ForeColor = Color.FromArgb(212, 212, 212);
        ed.WordWrap = false;
        ed.AcceptsTab = true;
        ed.TextChanged += delegate { debounce.Stop(); debounce.Start(); };
        ed.KeyUp += delegate (object s, KeyEventArgs e) { ActualizarPopup(); };
        ed.KeyDown += new KeyEventHandler(TeclaEditor);
        ed.Leave += delegate { EsconderPopup(); };
        split.Panel1.Controls.Add(ed);

        // Recuadro 100% visual: Panel hijo + Label. No es seleccionable,
        // no toma foco con clics, no acepta teclas. Solo muestra.
        popPanel = new Panel();
        popPanel.Size = new Size(340, 170);
        popPanel.BorderStyle = BorderStyle.FixedSingle;
        popPanel.BackColor = Color.FromArgb(37, 37, 38);
        popPanel.Visible = false;
        popPanel.TabStop = false;
        lblPop = new Label();
        lblPop.Dock = DockStyle.Fill;
        lblPop.Font = new Font("Consolas", 11);
        lblPop.BackColor = Color.FromArgb(37, 37, 38);
        lblPop.ForeColor = Color.FromArgb(156, 220, 254);
        popPanel.Controls.Add(lblPop);
        split.Panel1.Controls.Add(popPanel);

        var der = new TableLayoutPanel();
        der.Dock = DockStyle.Fill;
        der.RowCount = 3;
        der.ColumnCount = 1;
        der.RowStyles.Add(new RowStyle(SizeType.Percent, 26));
        der.RowStyles.Add(new RowStyle(SizeType.Percent, 38));
        der.RowStyles.Add(new RowStyle(SizeType.Percent, 36));
        der.BackColor = Color.FromArgb(30, 30, 30);
        split.Panel2.Controls.Add(der);

        var g1 = NuevoGrupo("LSP en vivo (problemas, clic para ir)");
        lstProb = new ListBox();
        lstProb.Dock = DockStyle.Fill;
        lstProb.Font = new Font("Consolas", 10);
        lstProb.BackColor = Color.FromArgb(37, 37, 38);
        lstProb.ForeColor = Color.FromArgb(212, 212, 212);
        lstProb.DoubleClick += delegate { IrAProblema(); };
        g1.Controls.Add(lstProb);
        der.Controls.Add(g1, 0, 0);

        var g2 = NuevoGrupo("Diccionario");
        txtBuscar = new TextBox();
        txtBuscar.Dock = DockStyle.Top;
        txtBuscar.Font = new Font("Consolas", 10);
        txtBuscar.BackColor = Color.FromArgb(60, 60, 60);
        txtBuscar.ForeColor = Color.White;
        txtBuscar.TextChanged += delegate { PintarDict(); };
        var lblBuscar = new Label();
        lblBuscar.Text = "buscar… (escribe para filtrar)";
        lblBuscar.Dock = DockStyle.Top;
        lblBuscar.ForeColor = Color.Gray;
        lblBuscar.Font = new Font("Consolas", 9);
        g2.Controls.Add(lstDict = NuevaListaDict());
        g2.Controls.Add(txtBuscar);
        g2.Controls.Add(lblBuscar);
        der.Controls.Add(g2, 0, 1);

        var g3 = NuevoGrupo("Salida");
        txtOut = new RichTextBox();
        txtOut.Dock = DockStyle.Fill;
        txtOut.Font = new Font("Consolas", 10);
        txtOut.BackColor = Color.FromArgb(37, 37, 38);
        txtOut.ForeColor = Color.FromArgb(212, 212, 212);
        txtOut.ReadOnly = true;
        txtOut.WordWrap = false;
        g3.Controls.Add(txtOut);
        der.Controls.Add(g3, 0, 2);

        var status = new StatusStrip();
        status.Dock = DockStyle.Fill;
        st = new ToolStripStatusLabel("Listo.");
        status.Items.Add(st);
        raiz.Controls.Add(status, 0, 2);

        debounce = new Timer();
        debounce.Interval = 800;
        debounce.Tick += delegate { debounce.Stop(); RevisarEnVivo(); };

        ed.Text = EjemploOleada();
        PintarDict();
        if (comaExe == "")
        {
            var preg = MessageBox.Show(
                "No encuentro coma.exe.\n¿Quieres señalar dónde está? (se recuerda)",
                ".Coma IDE", MessageBoxButtons.YesNo, MessageBoxIcon.Question);
            if (preg == DialogResult.Yes)
            {
                var dlg = new OpenFileDialog();
                dlg.Filter = "coma.exe|coma.exe|Todos|*.*";
                dlg.FileName = "coma.exe";
                if (dlg.ShowDialog(this) == DialogResult.OK && File.Exists(dlg.FileName))
                {
                    comaExe = dlg.FileName;
                    RecordarComa(comaExe);
                    OrigenComa = "elegido";
                }
            }
        }
        PonEstado(comaExe == "" ? "OJO: no encuentro coma.exe (Ejecutar te lo pedirá)." : "Compilador (" + OrigenComa + "): " + comaExe);
        KeyPreview = true;
        KeyDown += new KeyEventHandler(TeclaForma);
        ActiveControl = ed;
        Shown += delegate { ed.Focus(); ed.Select(0, 0); PonEstado("Tab=elegir primera · Enter=normal · Esc=cerrar"); };
    }

    void TeclaForma(object s, KeyEventArgs e)
    {
        if (e.Control && e.KeyCode == Keys.G) { GuardarDiario(); e.Handled = true; }
        else if (e.KeyCode == Keys.F5) { Ejecutar(); e.Handled = true; }
    }

    // ---- Autocompletado estilo GameMaker: recuadro bajo el cursor ----
    static bool EsLetra(char c)
    {
        return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
               (c >= '0' && c <= '9') || c == '_' || c >= 128;
    }

    void PalabraActual(out int ini, out string pedazo)
    {
        int caret = ed.SelectionStart;
        ini = caret;
        while (ini > 0 && EsLetra(ed.Text[ini - 1])) ini--;
        pedazo = ed.Text.Substring(ini, caret - ini);
    }

    void ActualizarPopup()
    {
        int ini;
        string pedazo;
        PalabraActual(out ini, out pedazo);
        if (pedazo.Length < 1)
        {
            EsconderPopup();
            return;
        }
        bool en = cmbLang.SelectedIndex == 1;
        sugs = MotorSugerir.Sugerir(pedazo, en);
        if (sugs.Count == 0) { EsconderPopup(); return; }
        popIni = ini;
        var sb = new StringBuilder();
        foreach (Sugerencia sg in sugs) sb.AppendLine(sg.Texto);
        sb.Append("Tab = elegir la primera");
        lblPop.Text = sb.ToString();
        if (headless) { popPanel.Visible = true; return; }
        try
        {
            Control padre = ed.Parent;
            Point pt = ed.GetPositionFromCharIndex(ed.SelectionStart);
            int px = ed.Location.X + pt.X;
            int py = ed.Location.Y + pt.Y + 22;
            if (padre != null)
            {
                if (px + popPanel.Width > padre.Width) px = padre.Width - popPanel.Width;
                if (py + popPanel.Height > padre.Height) py = pt.Y - popPanel.Height - 4;
            }
            if (px < 0) px = 0;
            if (py < 0) py = 0;
            popPanel.Location = new Point(px, py);
        }
        catch { }
        popPanel.Visible = true;
        popPanel.BringToFront();
    }

    // Prueba determinista del popup sin ventanas ni teclado (para --uitest).
    public string EjecutarUiTest()
    {
        headless = true;
        var sb = new StringBuilder();
        ed.Text = "mue";
        ed.SelectionStart = 3;
        ActualizarPopup();
        string top = sugs.Count > 0 ? sugs[0].Palabra : "?";
        sb.Append("popup=" + (lblPop.Text.IndexOf("muestra") >= 0 && top == "muestra" ? "OK" : "FALLO"));
        ManejarTeclaPopup(Keys.Tab);
        sb.Append(" texto=" + ed.Text);
        sb.Append(" oculto=" + (!popPanel.Visible ? "OK" : "FALLO"));
        ManejarTeclaPopup(Keys.Escape);
        bool ok = ed.Text == "muestra";
        bool inter1 = EsInteractivo("tick 60.\n mostrar Tecla.\nfin.\n");
        bool inter2 = !EsInteractivo("mostrar 40 mas 2.\n");
        bool inter3 = !EsInteractivo("mostrar \"pulsa una tecla para entrar.\".\n");
        sb.Append(" inter=" + (inter1 && inter2 && inter3 ? "OK" : "FALLO"));
        ok = ok && inter1 && inter2 && inter3;
        sb.Append(ok ? " PASS" : " FAIL");
        return sb.ToString();
    }

    void EsconderPopup()
    {
        if (popPanel != null) popPanel.Visible = false;
    }

    void CompletarTop()
    {
        if (sugs.Count == 0) return;
        string palabra = sugs[0].Palabra;
        int caret = ed.SelectionStart;
        ed.Select(popIni, caret - popIni);
        ed.SelectedText = palabra;
        EsconderPopup();
        PonEstado("Tab: " + palabra + " insertado");
    }

    // Tab completa la primera sugerencia; Enter siempre es Enter natural;
    // Esc esconde. El popup es solo visual: no se navega, no se clickea.
    // Devuelve true si la tecla quedó manejada.
    bool ManejarTeclaPopup(Keys data)
    {
        if (!popPanel.Visible && !headless) return false;
        if (data == Keys.Tab)
        {
            CompletarTop();
            return true;
        }
        if (data == Keys.Escape)
        {
            EsconderPopup();
            return true;
        }
        return false;
    }

    void TeclaEditor(object s, KeyEventArgs e)
    {
        Keys data = e.KeyCode | e.Modifiers;
        if (ManejarTeclaPopup(data))
        {
            e.Handled = true;
            e.SuppressKeyPress = true;
        }
    }

    protected override bool ProcessCmdKey(ref Message msg, Keys keyData)
    {
        if (ManejarTeclaPopup(keyData)) return true;
        return base.ProcessCmdKey(ref msg, keyData);
    }

    ListBox NuevaListaDict()
    {
        var l = new ListBox();
        l.Dock = DockStyle.Fill;
        l.Font = new Font("Consolas", 10);
        l.BackColor = Color.FromArgb(37, 37, 38);
        l.ForeColor = Color.FromArgb(156, 220, 254);
        return l;
    }

    GroupBox NuevoGrupo(string t)
    {
        var g = new GroupBox();
        g.Text = t;
        g.Dock = DockStyle.Fill;
        g.ForeColor = Color.Gray;
        g.Font = new Font("Consolas", 9);
        return g;
    }

    Button NuevoBoton(string t)
    {
        var b = new Button();
        b.Text = t;
        b.AutoSize = true;
        b.BackColor = Color.FromArgb(14, 99, 156);
        b.ForeColor = Color.White;
        b.FlatStyle = FlatStyle.Flat;
        return b;
    }

    public static string OrigenComa = "";

    public static string BuscarComa()
    {
        string aqui = Path.GetDirectoryName(Application.ExecutablePath);
        var cands = new List<KeyValuePair<string, string>>();
        cands.Add(new KeyValuePair<string, string>(Path.Combine(aqui, "coma.exe"), "misma carpeta"));
        string d = aqui;
        for (int i = 0; i < 4 && d != null; i++)
        {
            cands.Add(new KeyValuePair<string, string>(
                Path.Combine(d, "nim" + Path.DirectorySeparatorChar + "coma.exe"), "subida"));
            d = Path.GetDirectoryName(d);
        }
        foreach (KeyValuePair<string, string> c in cands)
        {
            try { if (File.Exists(c.Key)) { OrigenComa = c.Value; return Path.GetFullPath(c.Key); } }
            catch { }
        }
        try
        {
            string path = Environment.GetEnvironmentVariable("PATH") ?? "";
            foreach (string p in path.Split(';'))
            {
                string t = p.Trim().Trim('"');
                if (t == "") continue;
                string f = Path.Combine(t, "coma.exe");
                if (File.Exists(f)) { OrigenComa = "PATH"; return Path.GetFullPath(f); }
            }
        }
        catch { }
        try
        {
            string cfg = Path.Combine(aqui, "coma-ide.cfg");
            if (File.Exists(cfg))
            {
                string g = File.ReadAllText(cfg).Trim().Trim('"');
                if (g != "" && File.Exists(g)) { OrigenComa = "recordado"; return Path.GetFullPath(g); }
            }
        }
        catch { }
        OrigenComa = "no";
        return "";
    }

    public static void RecordarComa(string ruta)
    {
        try
        {
            string cfg = Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), "coma-ide.cfg");
            File.WriteAllText(cfg, ruta);
        }
        catch { }
    }

    void PonEstado(string s)
    {
        if (InvokeRequired) { Invoke(new Action<string>(PonEstado), s); return; }
        st.Text = s;
    }

    bool revisando = false;

    // ---- LSP en vivo ----
    void RevisarEnVivo()
    {
        if (comaExe == "" || corriendo || revisando) return;
        revisando = true;
        string codigo = "";
        Invoke(new Action(delegate { codigo = ed.Text; }));
        Task.Factory.StartNew(delegate
        {
            List<Problema> ps = PasarRevision(codigo);
            Invoke(new Action(delegate
            {
                Actualizar(ps);
                revisando = false;
            }));
        });
    }

    List<Problema> PasarRevision(string codigo)
    {
        var ps = new List<Problema>();
        try
        {
            string ses = Path.Combine(tmpDir, "rev.coma");
            File.WriteAllText(ses, codigo, new UTF8Encoding(false));
            string salida = Correr(comaExe, "\"" + ses + "\" --ir");
            foreach (string ln in salida.Split(new char[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries))
            {
                Match m = RxIssue.Match(ln.Trim());
                if (m.Success)
                {
                    var p = new Problema();
                    p.Linea = int.Parse(m.Groups[1].Value);
                    p.Col = int.Parse(m.Groups[2].Value);
                    p.Codigo = m.Groups[3].Value;
                    p.Nivel = m.Groups[4].Value;
                    p.Msg = m.Groups[5].Value.Trim();
                    ps.Add(p);
                }
            }
        }
        catch { }
        return ps;
    }

    void Actualizar(List<Problema> ps)
    {
        actual = ps ?? new List<Problema>();
        lstProb.Items.Clear();
        if (actual.Count == 0) lstProb.Items.Add("0 problemas — pinta bien.");
        else foreach (Problema p in actual) lstProb.Items.Add(p.ToString());
    }

    void IrAProblema()
    {
        if (lstProb.SelectedItem == null || !(lstProb.SelectedItem is Problema)) return;
        var p = (Problema)lstProb.SelectedItem;
        string[] lineas = ed.Text.Split('\n');
        if (p.Linea < 1 || p.Linea > lineas.Length) return;
        int pos = 0;
        for (int i = 0; i < p.Linea - 1; i++) pos += lineas[i].Length + 1;
        ed.Focus();
        ed.Select(pos, lineas[p.Linea - 1].Length);
        ed.ScrollToCaret();
    }

    static string Correr(string exe, string args)
    {
        var psi = new ProcessStartInfo(exe, args);
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;
        psi.StandardOutputEncoding = Encoding.UTF8;
        var pr = Process.Start(psi);
        string so = pr.StandardOutput.ReadToEnd();
        string se = pr.StandardError.ReadToEnd();
        pr.WaitForExit();
        return so + "\n" + se;
    }

    // Corre un proceso mostrando cada línea en vivo. Devuelve el exit code.
    static int CorrerLineas(string exe, string args, string workDir, Action<string> onLinea, int timeoutMs)
    {
        var psi = new ProcessStartInfo(exe, args);
        psi.UseShellExecute = false;
        psi.CreateNoWindow = true;
        psi.RedirectStandardOutput = true;
        psi.RedirectStandardError = true;
        psi.StandardOutputEncoding = Encoding.UTF8;
        if (workDir != null && workDir != "") psi.WorkingDirectory = workDir;
        var pr = new Process();
        pr.StartInfo = psi;
        pr.OutputDataReceived += delegate (object s, DataReceivedEventArgs e)
        {
            if (e.Data != null) onLinea(e.Data);
        };
        pr.ErrorDataReceived += delegate (object s, DataReceivedEventArgs e)
        {
            if (e.Data != null) onLinea(e.Data);
        };
        pr.Start();
        pr.BeginOutputReadLine();
        pr.BeginErrorReadLine();
        bool salio = pr.WaitForExit(timeoutMs);
        if (!salio)
        {
            try { pr.Kill(); } catch { }
            pr.WaitForExit(3000);
            return -1;
        }
        return pr.ExitCode;
    }

    void PonLinea(string s)
    {
        if (InvokeRequired) { Invoke(new Action<string>(PonLinea), s); return; }
        txtOut.AppendText(s + "\r\n");
        txtOut.SelectionStart = txtOut.Text.Length;
        txtOut.ScrollToCaret();
    }

    // ¿El programa necesita consola de verdad (teclado/juego)? Se quitan
    // textos "..." y comentarios |...| y se buscan tick/tecla/mando.
    static bool EsInteractivo(string codigo)
    {
        var sb = new StringBuilder(codigo.Length);
        bool instr = false;
        for (int i = 0; i < codigo.Length; i++)
        {
            char c = codigo[i];
            if (!instr && c == '"') { instr = true; sb.Append(' '); }
            else if (instr && c == '"')
            {
                if (i + 1 < codigo.Length && codigo[i + 1] == '"') { sb.Append("  "); i++; }
                else { instr = false; sb.Append(' '); }
            }
            else if (instr) sb.Append(' ');
            else sb.Append(c);
        }
        string[] lineas = sb.ToString().Split('\n');
        var limpio = new StringBuilder();
        foreach (string ln in lineas)
        {
            string t = ln;
            int p = t.IndexOf('|');
            if (p >= 0) t = t.Substring(0, p);
            limpio.AppendLine(t);
        }
        var rx = new Regex("\\b(tick|ticks|turbo|tecla|key|mando)\\b", RegexOptions.IgnoreCase);
        return rx.IsMatch(limpio.ToString());
    }

    // ---- Ejecutar ----
    void PedirComa()
    {
        var dlg = new OpenFileDialog();
        dlg.Filter = "coma.exe|coma.exe|Todos|*.*";
        dlg.FileName = "coma.exe";
        if (dlg.ShowDialog(this) == DialogResult.OK && File.Exists(dlg.FileName))
        {
            comaExe = dlg.FileName;
            RecordarComa(comaExe);
            OrigenComa = "elegido";
            PonEstado("Compilador (" + OrigenComa + "): " + comaExe);
        }
    }

    void Ejecutar()
    {
        if (comaExe == "")
        {
            PedirComa();
            if (comaExe == "") { txtOut.Text = "Sin compilador no hay ejecución. Señala coma.exe para seguir."; return; }
        }
        if (corriendo) return;
        corriendo = true;
        bRun.Enabled = false;
        PonEstado("Compilando (rápido)…");
        txtOut.Clear();
        string codigo = ed.Text;
        Task.Factory.StartNew(delegate
        {
            bool ok = false;
            try
            {
                string ses = Path.Combine(tmpDir, "prog.coma");
                string exe = Path.Combine(tmpDir, "prog.exe");
                try { if (File.Exists(exe)) File.Delete(exe); }
                catch { }
                File.WriteAllText(ses, codigo, new UTF8Encoding(false));
                PonLinea("$ coma prog.coma --opt:0");
                int rc = CorrerLineas(comaExe, "\"" + ses + "\" --opt:0", tmpDir, new Action<string>(PonLinea), 600000);
                if (!File.Exists(exe) || rc != 0)
                {
                    PonLinea("No compiló (código " + rc + "). Mira el LSP en vivo.");
                    ok = false;
                }
                else
                {
                    ok = true;
                    PonEstado("Ejecutando…");
                    if (EsInteractivo(codigo))
                    {
                        PonLinea("Juego interactivo: se abre en su propia ventana (ciérrala para seguir).");
                        var psi = new ProcessStartInfo(exe);
                        psi.UseShellExecute = true;
                        psi.WorkingDirectory = tmpDir;
                        Process.Start(psi);
                    }
                    else
                    {
                        int r2 = CorrerLineas(exe, "", tmpDir, new Action<string>(PonLinea), 15000);
                        if (r2 == -1) PonLinea("(se detuvo a los 15 s: el programa no termina solo)");
                    }
                }
            }
            catch (Exception ex) { PonLinea("Error del IDE: " + ex.Message); ok = false; }
            Invoke(new Action(delegate
            {
                corriendo = false;
                bRun.Enabled = true;
                PonEstado(ok ? "Listo." : "Revisa los errores.");
                RevisarEnVivo();
            }));
        });
    }

    // ---- Diario ----
    void GuardarDiario()
    {
        try
        {
            string f = Path.Combine(Environment.CurrentDirectory,
                "sesion-" + DateTime.Now.ToString("yyyyMMdd-HHmmss") + ".log");
            var sb = new StringBuilder();
            sb.AppendLine("== diario .Coma IDE " + DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + " ==");
            sb.AppendLine("--- codigo ---");
            sb.AppendLine(ed.Text);
            sb.AppendLine("--- problemas (" + actual.Count + ") ---");
            foreach (Problema p in actual) sb.AppendLine(p.ToString());
            sb.AppendLine("--- salida ---");
            sb.AppendLine(txtOut.Text);
            File.WriteAllText(f, sb.ToString(), new UTF8Encoding(false));
            PonEstado("Diario guardado en " + f + ". Para el resto de tu vida.");
        }
        catch (Exception ex) { PonEstado("No pude guardar el diario: " + ex.Message); }
    }

    // ---- Diccionario ----
    void PintarDict()
    {
        bool en = cmbLang.SelectedIndex == 1;
        string q = txtBuscar.Text.Trim().ToLowerInvariant();
        lstDict.Items.Clear();
        foreach (string[] e in DictData.Entradas)
        {
            string aliases = en ? e[2] : e[1];
            if (q != "" && e[0].IndexOf(q, StringComparison.OrdinalIgnoreCase) < 0
                && aliases.IndexOf(q, StringComparison.OrdinalIgnoreCase) < 0) continue;
            lstDict.Items.Add(e[0] + "  =  " + aliases);
        }
        if (lstDict.Items.Count == 0) lstDict.Items.Add("sin resultados");
    }

    void CargarEjemplo()
    {
        int i = cmbEx.SelectedIndex;
        if (i == 1) ed.Text = EjemploOleada();
        else if (i == 2) ed.Text = EjemploWave();
        else if (i == 3) ed.Text = EjemploHumano();
        cmbEx.SelectedIndex = 0;
    }

    static string EjemploOleada()
    {
        return "Jefe1 igual registro Vida 30 y Ataque 5.\nJefe2 igual registro Vida 50 y Ataque 8.\nEnemigos igual lista Jefe1 y Jefe2.\nDaño_total igual 0.\npor cada E en Enemigos.\n    Daño_total igual Daño_total más Ataque de E.\nfin.\nmostrar Daño_total.\n";
    }

    static string EjemploWave()
    {
        return "Boss1 equal record Health 30 and Attack 5.\nBoss2 equal record Health 50 and Attack 8.\nEnemies equal list Boss1 and Boss2.\nTotal_damage equal 0.\nfor each E in Enemies.\n    Total_damage equal Total_damage plus Attack of E.\nend.\nprint Total_damage.\n";
    }

    static string EjemploHumano()
    {
        return "Heroe igual registro Vida 12 y Ataque 2.\nde en caso de que la Vida de el Heroe es menor a 1.\n    mostrar \"Muerto.\".\nfin.\nmostrar \"Vivo.\".\n";
    }
}

static class Program
{
    [STAThread]
    static void Main(string[] args)
    {
        if (args.Length > 0 && args[0] == "--findcoma")
        {
            string r = IdeForm.BuscarComa();
            Console.WriteLine(r == "" ? "no encontrado" : r + "  [" + IdeForm.OrigenComa + "]");
            Environment.ExitCode = r == "" ? 1 : 0;
            return;
        }
        if (args.Length > 0 && args[0] == "--uitest")
        {
            IdeForm f = new IdeForm();
            string r = f.EjecutarUiTest();
            Console.WriteLine(r);
            Environment.ExitCode = r.IndexOf("PASS") >= 0 ? 0 : 1;
            return;
        }
        if (args.Length > 0 && args[0] == "--selftest")
        {
            int n = DictData.Entradas.Length;
            Console.WriteLine("diccionario: " + n + " entradas");
            var rx = new Regex(@"^linea (\d+):(\d+) \[([A-Z]\d+) (\w+)\]: (.*)$");
            Match m = rx.Match("linea 10:11 [E001 error]: falta el punto final '.' en la sentencia");
            Console.WriteLine("regex: " + (m.Success && m.Groups[1].Value == "10" && m.Groups[3].Value == "E001" ? "OK" : "FALLO"));
            List<Sugerencia> s1 = MotorSugerir.Sugerir("mue", false);
            List<Sugerencia> s2 = MotorSugerir.Sugerir("show", true);
            List<Sugerencia> s3 = MotorSugerir.Sugerir("menor", false);
            string top1 = s1.Count > 0 ? s1[0].Palabra : "?";
            string top2 = s2.Count > 0 ? s2[0].Palabra : "?";
            bool hayMenor = false;
            foreach (Sugerencia sg in s3) if (sg.Canon == "es_menor_que") hayMenor = true;
            Console.WriteLine("sugerir(mue): " + top1 + " | sugerir(show): " + top2 + " | menor->es_menor_que: " + (hayMenor ? "OK" : "FALLO"));
            bool ok = n >= 60 && m.Success && top1 == "muestra" && top2 == "show" && hayMenor;
            Console.WriteLine(ok ? "SELFTEST OK" : "SELFTEST FALLO");
            Environment.ExitCode = ok ? 0 : 1;
            return;
        }
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        Application.Run(new IdeForm());
    }
}
