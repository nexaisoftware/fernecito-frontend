/// Skeleton loaders por pantalla: inicio (app), mi perfil, cartelera, actividad, perfil local.
library;

import 'package:flutter/cupertino.dart';
import '../core/constants.dart';
import 'shimmer_skeleton.dart';

/// Skeleton genérico solo para verificación de sesión (app init).
/// No imita perfil ni login: logo + una línea, para no confundir con cartelera/perfil.
class SkeletonPantallaInicio extends StatelessWidget {
  const SkeletonPantallaInicio({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ShimmerBox(width: 56, height: 56, borderRadius: 14),
              const SizedBox(height: 20),
              ShimmerLine(width: 140, height: 14, borderRadius: 6),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton para Mi cuenta Fernecito (mi perfil).
class SkeletonPantallaMiPerfil extends StatelessWidget {
  const SkeletonPantallaMiPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ShimmerLine(width: 160, height: 20),
                const SizedBox(height: 20),
                ShimmerCircle(size: 120),
                const SizedBox(height: 20),
                ShimmerLine(width: 140, height: 18),
                const SizedBox(height: 8),
                ShimmerLine(width: 100, height: 14),
                const SizedBox(height: 24),
                ShimmerBox(width: double.infinity, height: 48, borderRadius: 50),
                const SizedBox(height: 16),
                ShimmerBox(width: double.infinity, height: 56, borderRadius: 12),
                const SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 56, borderRadius: 12),
                const SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 56, borderRadius: 12),
                const SizedBox(height: 28),
                ShimmerLine(width: 120, height: 18),
                const SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 64, borderRadius: 12),
                const SizedBox(height: 12),
                ShimmerBox(width: double.infinity, height: 64, borderRadius: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skeleton para la cartelera (home): logo, buscador, cards.
class SkeletonPantallaCartelera extends StatelessWidget {
  const SkeletonPantallaCartelera({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(
                  children: [
                    ShimmerBox(width: 40, height: 40, borderRadius: 12),
                    const SizedBox(width: 12),
                    ShimmerLine(width: 120, height: 28),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: double.infinity, height: 42, borderRadius: 50),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ShimmerBox(width: 70, height: 32, borderRadius: 50),
                        const SizedBox(width: 8),
                        ShimmerBox(width: 80, height: 32, borderRadius: 50),
                        const SizedBox(width: 8),
                        ShimmerBox(width: 60, height: 32, borderRadius: 50),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: ShimmerLine(width: 100, height: 18),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 280,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ShimmerBox(
                        width: 160,
                        height: 260,
                        borderRadius: 16,
                      ),
                    );
                  },
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

/// Skeleton para Mi actividad (lista de cards).
class SkeletonPantallaActividad extends StatelessWidget {
  const SkeletonPantallaActividad({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: ShimmerLine(width: 200, height: 20),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerBox(width: 80, height: 80 * (16 / 9), borderRadius: 12),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ShimmerLine(width: double.infinity, height: 16),
                                    const SizedBox(height: 8),
                                    ShimmerLine(width: double.infinity, height: 12),
                                    ShimmerLine(width: 120, height: 12),
                                    const SizedBox(height: 8),
                                    ShimmerBox(width: 80, height: 24, borderRadius: 20),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(child: ShimmerBox(height: 44, borderRadius: 50)),
                              const SizedBox(width: 8),
                              Expanded(child: ShimmerBox(height: 44, borderRadius: 50)),
                              const SizedBox(width: 8),
                              Expanded(child: ShimmerBox(height: 44, borderRadius: 50)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton para perfil del local (avatar, botón, carruseles).
class SkeletonPantallaLocalPerfil extends StatelessWidget {
  const SkeletonPantallaLocalPerfil({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ColoresApp.fondoPrincipal,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  children: [
                    ShimmerCircle(size: 100),
                    const SizedBox(height: 12),
                    ShimmerLine(width: 180, height: 22),
                    const SizedBox(height: 8),
                    ShimmerLine(width: 100, height: 14),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ShimmerBox(width: 160, height: 48, borderRadius: 50),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 10),
                child: ShimmerLine(width: 120, height: 18),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 280,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: ShimmerBox(
                        width: 210,
                        height: 280,
                        borderRadius: 16,
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 10),
                child: ShimmerLine(width: 200, height: 18),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: 4,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ShimmerBox(
                        width: 140,
                        height: 220,
                        borderRadius: 16,
                      ),
                    );
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
                child: ShimmerLine(width: 150, height: 18),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  children: List.generate(
                    3,
                    (_) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ShimmerBox(
                        width: double.infinity,
                        height: 76,
                        borderRadius: 50,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
