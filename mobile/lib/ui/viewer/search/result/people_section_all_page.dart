import "dart:async";

import 'package:flutter/material.dart';
import "package:flutter_animate/flutter_animate.dart";
import "package:photos/events/event.dart";
import "package:photos/generated/l10n.dart";
import "package:photos/models/search/generic_search_result.dart";
import "package:photos/models/search/hierarchical/face_filter.dart";
import "package:photos/models/search/search_types.dart";
import "package:photos/models/selected_people.dart";
import "package:photos/theme/ente_theme.dart";
import "package:photos/ui/common/loading_widget.dart";
import "package:photos/ui/viewer/search_tab/people_section.dart";

class PeopleSectionAllPage extends StatelessWidget {
  const PeopleSectionAllPage({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(SectionType.face.sectionTitle(context)),
        centerTitle: false,
      ),
      body: const PeopleSectionAllWidget(),
    );
  }
}

class PeopleSectionAllWidget extends StatefulWidget {
  const PeopleSectionAllWidget({
    super.key,
    this.selectedPeople,
    this.namedOnly = false,
  });

  final SelectedPeople? selectedPeople;
  final bool namedOnly;

  @override
  State<PeopleSectionAllWidget> createState() => _PeopleSectionAllWidgetState();
}

class _PeopleSectionAllWidgetState extends State<PeopleSectionAllWidget> {
  late Future<List<GenericSearchResult>> sectionData;
  final streamSubscriptions = <StreamSubscription>[];

  @override
  void initState() {
    super.initState();
    sectionData = getResults();

    final streamsToListenTo = SectionType.face.viewAllUpdateEvents();
    for (Stream<Event> stream in streamsToListenTo) {
      streamSubscriptions.add(
        stream.listen((event) async {
          setState(() {
            sectionData = getResults();
          });
        }),
      );
    }
  }

  Future<List<GenericSearchResult>> getResults() async {
    final results =
        List<GenericSearchResult>.from(await SectionType.face.getData(context));

    if (widget.namedOnly) {
      results.removeWhere(
        (element) =>
            (element.hierarchicalSearchFilter as FaceFilter).personId == null,
      );
      if (widget.selectedPeople?.personIds.isEmpty ?? false) {
        widget.selectedPeople!.select(
          results
              .take(2)
              .map((e) => (e.hierarchicalSearchFilter as FaceFilter).personId!)
              .toSet(),
        );
      }
    }
    return results;
  }

  @override
  void dispose() {
    for (var subscriptions in streamSubscriptions) {
      subscriptions.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final smallFontSize = getEnteTextTheme(context).small.fontSize!;
    final textScaleFactor =
        MediaQuery.textScalerOf(context).scale(smallFontSize) / smallFontSize;
    const horizontalEdgePadding = 20.0;
    const gridPadding = 16.0;

    return FutureBuilder<List<GenericSearchResult>>(
      future: sectionData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: EnteLoadingWidget());
        } else if (snapshot.hasError) {
          return const Center(child: Icon(Icons.error_outline_rounded));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text(S.of(context).noResultsFound + '.'));
        } else {
          final results = snapshot.data!;
          final screenWidth = MediaQuery.of(context).size.width;
          final crossAxisCount = (screenWidth / 100).floor();

          final itemSize = (screenWidth -
                  ((horizontalEdgePadding * 2) +
                      ((crossAxisCount - 1) * gridPadding))) /
              crossAxisCount;

          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(
              horizontalEdgePadding,
              16,
              horizontalEdgePadding,
              96,
            ),
            shrinkWrap: true,
            primary: false,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              mainAxisSpacing: gridPadding,
              crossAxisSpacing: gridPadding,
              crossAxisCount: crossAxisCount,
              childAspectRatio: itemSize / (itemSize + (24 * textScaleFactor)),
            ),
            itemCount: results.length,
            itemBuilder: (context, index) {
              return PersonSearchExample(
                searchResult: results[index],
                size: itemSize,
                selectedPeople: widget.selectedPeople,
              )
                  .animate(delay: Duration(milliseconds: index * 13))
                  .fadeIn(
                    duration: const Duration(milliseconds: 225),
                    curve: Curves.easeIn,
                  )
                  .slide(
                    begin: const Offset(0, -0.06),
                    curve: Curves.easeInOut,
                    duration: const Duration(
                      milliseconds: 225,
                    ),
                  );
            },
          );
        }
      },
    );
  }
}
