import { Component, inject } from '@angular/core';
import { ActivatedRoute } from '@angular/router';

/** Página temporal para Registro / Login / Carrito (se construirán en las siguientes partes) */
@Component({
  selector: 'app-placeholder',
  template: `
    <section class="ph">
      <h1>{{ titulo }}</h1>
      <p>Esta sección se construirá en la siguiente parte.</p>
    </section>
  `,
  styles: `.ph { min-height: 100vh; padding: 120px 16px; text-align: center; }`,
})
export class Placeholder {
  protected readonly titulo = inject(ActivatedRoute).snapshot.data['titulo'] as string;
}
