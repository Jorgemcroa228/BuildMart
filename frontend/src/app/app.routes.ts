import { Routes } from '@angular/router';
import { Home } from './pages/home/home';
import { Login } from './pages/login/login';
import { Registro } from './pages/registro/registro';
import { Placeholder } from './pages/placeholder/placeholder';

export const routes: Routes = [
  { path: '', component: Home },
  { path: 'registro', component: Registro, title: 'Registrarse | BuildMart' },
  { path: 'login', component: Login, title: 'Iniciar sesión | BuildMart' },
  { path: 'recuperar-password', component: Placeholder, data: { titulo: 'Recuperar contraseña' } },
  { path: 'carrito', component: Placeholder, data: { titulo: 'Carrito de compras' } },
  { path: '**', redirectTo: '' },
];
