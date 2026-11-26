import { Component } from '@angular/core';
import { HeroVideo } from '../../components/hero-video/hero-video';

@Component({
  selector: 'app-home',
  imports: [HeroVideo],
  template: `
    <app-hero-video />
    <!-- Próximas partes: catálogo, buscador, etc. -->
    <section class="proximamente">
      <h2>Catálogo</h2>
      <p>Próximamente: productos desde la base de datos tienda_web.</p>
    </section>
  `,
  styles: `
    .proximamente { min-height: 60vh; padding: 64px 16px; text-align: center; }
  `,
})
export class Home {}
