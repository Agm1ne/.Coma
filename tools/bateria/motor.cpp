// DLL de juguete para la bateria: C plano + C++ mangled + constante.
#include <cstdint>

extern "C" {

__declspec(dllexport) int CuarentaYDos() { return 42; }

__declspec(dllexport) int64_t CrearMotor() {
    int* p = new int(42);
    return (int64_t)p;
}

__declspec(dllexport) int64_t MotorValor(int64_t h) {
    return (int64_t)(*(int*)h);
}

__declspec(dllexport) int64_t MotorDoble(int64_t h) {
    int* p = (int*)h;
    *p = *p * 2;
    return (int64_t)p;
}

__declspec(dllexport) void DestruirMotor(int64_t h) {
    delete (int*)h;
}

__declspec(dllexport) int64_t CrearCaja(int64_t v);

} // extern "C"

struct Caja {
    int64_t v;
    int64_t triple() { return v * 3; }
};

__declspec(dllexport) int64_t CajaTriple(Caja* c) {
    return c->triple();
}

extern "C" {
__declspec(dllexport) int64_t CrearCaja(int64_t v) {
    Caja* c = new Caja();
    c->v = v;
    return (int64_t)c;
}

static int el42 = 42;
static double elpi = 3.5;
static const char* elhola = "hola";

__declspec(dllexport) int64_t DamePuntero() { return (int64_t)&el42; }
__declspec(dllexport) int64_t DamePi() { return (int64_t)&elpi; }
__declspec(dllexport) int64_t DameHola() { return (int64_t)elhola; }
} // extern "C"
