import { AfterViewInit, Component, ElementRef, viewChild } from '@angular/core';

@Component({
  selector: 'app-hero-video',
  templateUrl: './hero-video.html',
  styleUrl: './hero-video.scss',
})
export class HeroVideo implements AfterViewInit {
  private readonly video = viewChild.required<ElementRef<HTMLVideoElement>>('video');

  ngAfterViewInit(): void {
    // Algunos navegadores ignoran el atributo "muted" del template: se fuerza por código
    const v = this.video().nativeElement;
    v.muted = true;
    v.play().catch(() => {
      /* autoplay bloqueado: queda el fondo de respaldo */
    });
  }
}
