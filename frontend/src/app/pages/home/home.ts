import { Component } from '@angular/core';
import { GaleriaEspiral } from '../../components/galeria-espiral/galeria-espiral';
import { HeroVideo } from '../../components/hero-video/hero-video';

@Component({
  selector: 'app-home',
  imports: [HeroVideo, GaleriaEspiral],
  template: `
    <app-hero-video />
    <app-galeria-espiral />
    <!-- Próximas partes: catálogo, buscador, etc. -->
    <section class="proximamente">
      <h2>Catálogo</h2>
      <p>Próximamente: productos desde la base de datos tienda_web.</p>
    </section>
  `,
  styles: `
    .proximamente { min-height: 60vh; padding: 64px 16px; text-align: center; color: #e6edf3; }
  `,
})
export class Home {}
