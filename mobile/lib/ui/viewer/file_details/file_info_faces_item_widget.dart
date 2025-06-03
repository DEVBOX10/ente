import "package:flutter/foundation.dart" show kDebugMode;
import "package:flutter/material.dart";
import "package:logging/logging.dart";
import "package:photos/db/ml/db.dart";
import "package:photos/generated/l10n.dart";
import "package:photos/models/file/file.dart";
import "package:photos/models/ml/face/face.dart";
import "package:photos/models/ml/face/person.dart";
import "package:photos/services/machine_learning/face_ml/face_filtering/face_filtering_constants.dart";
import "package:photos/services/machine_learning/face_ml/feedback/cluster_feedback.dart";
import "package:photos/services/machine_learning/face_ml/person/person_service.dart";
import "package:photos/ui/components/buttons/chip_button_widget.dart";
import "package:photos/ui/components/info_item_widget.dart";
import "package:photos/ui/viewer/file_details/file_info_face_widget.dart";
import "package:photos/utils/face/face_thumbnail_cache.dart";

final Logger _logger = Logger("FacesItemWidget");

class FacesItemWidget extends StatefulWidget {
  final EnteFile file;
  const FacesItemWidget(this.file, {super.key});

  @override
  State<FacesItemWidget> createState() => _FacesItemWidgetState();
}

class _FacesItemWidgetState extends State<FacesItemWidget> {
  @override
  void initState() {
    super.initState();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return InfoItemWidget(
      key: const ValueKey("Faces"),
      leadingIcon: Icons.face_retouching_natural_outlined,
      subtitleSection: _faceWidgets(context, widget.file),
      hasChipButtons: true,
      biggerSpinner: true,
    );
  }

  Future<List<Widget>> _faceWidgets(BuildContext context, EnteFile file) async {
    final mlDataDB = MLDataDB.instance;
    try {
      if (file.uploadedFileID == null) {
        return [const NoFaceChipButtonWidget(NoFacesReason.fileNotUploaded)];
      }

      final List<Face>? faces =
          await mlDataDB.getFacesForGivenFileID(file.uploadedFileID!);
      if (faces == null) {
        return [const NoFaceChipButtonWidget(NoFacesReason.fileNotAnalyzed)];
      }

      // Remove faces with low scores
      if (!kDebugMode) {
        final beforeLength = faces.length;
        final lowScores = faces
            .where((face) => (face.score < kMinimumFaceShowScore))
            .toList();
        faces.removeWhere((face) => (face.score < kMinimumFaceShowScore));
        if (faces.length != beforeLength) {
          _logger.warning(
            'File ${file.uploadedFileID} has ${beforeLength - faces.length} faces with low scores ($lowScores) that are not shown in the UI',
          );
        }
      } else {
        faces.removeWhere((face) => (face.score < 0.5));
      }

      if (faces.isEmpty) {
        return [const NoFaceChipButtonWidget(NoFacesReason.noFacesFound)];
      }

      final faceIdsToClusterIds = await mlDataDB
          .getFaceIdsToClusterIds(faces.map((face) => face.faceID));
      final Map<String, PersonEntity> persons =
          await PersonService.instance.getPersonsMap();
      final clusterIDToPerson = await mlDataDB.getClusterIDToPersonID();

      // Sort faces by name and score
      final faceIdToPersonID = <String, String>{};
      for (final face in faces) {
        final clusterID = faceIdsToClusterIds[face.faceID];
        if (clusterID != null) {
          final personID = clusterIDToPerson[clusterID];
          if (personID != null) {
            faceIdToPersonID[face.faceID] = personID;
          }
        }
      }
      faces.sort((Face a, Face b) {
        final aPersonID = faceIdToPersonID[a.faceID];
        final bPersonID = faceIdToPersonID[b.faceID];
        if (aPersonID != null && bPersonID == null) {
          return -1;
        } else if (aPersonID == null && bPersonID != null) {
          return 1;
        } else {
          return b.score.compareTo(a.score);
        }
      });
      // Make sure hidden faces are last
      faces.sort((Face a, Face b) {
        final aIsHidden =
            persons[faceIdToPersonID[a.faceID]]?.data.isIgnored ?? false;
        final bIsHidden =
            persons[faceIdToPersonID[b.faceID]]?.data.isIgnored ?? false;
        if (aIsHidden && !bIsHidden) {
          return 1;
        } else if (!aIsHidden && bIsHidden) {
          return -1;
        } else {
          return 0;
        }
      });

      final lastViewedClusterID = ClusterFeedbackService.lastViewedClusterID;

      final faceWidgets = <FileInfoFaceWidget>[];

      final faceCrops = await getCachedFaceCrops(file, faces);
      final List<String> faceIDs = [];
      final List<double> faceScores = [];
      for (final Face face in faces) {
        final faceCrop = faceCrops != null ? faceCrops[face.faceID] : null;
        if (faceCrop == null) {
          _logger.severe(
            'Face crop for face ${face.faceID} in file ${file.uploadedFileID} is null, skipping face widget.',
          );
          return [
            const NoFaceChipButtonWidget(
              NoFacesReason.faceThumbnailGenerationFailed,
            ),
          ];
        }
        final String? clusterID = faceIdsToClusterIds[face.faceID];
        final PersonEntity? person = clusterIDToPerson[clusterID] != null
            ? persons[clusterIDToPerson[clusterID]!]
            : null;
        final highlight =
            (clusterID == lastViewedClusterID) && (person == null);
        faceIDs.add(face.faceID);
        faceScores.add(face.score);
        faceWidgets.add(
          FileInfoFaceWidget(
            file,
            face,
            faceCrop: faceCrop,
            clusterID: clusterID,
            person: person,
            highlight: highlight,
          ),
        );
      }

      _logger.info(
        'File ${file.uploadedFileID} has FaceIDs: $faceIDs with scores: $faceScores',
      );

      return faceWidgets;
    } catch (e, s) {
      _logger.severe('failed to get face widgets in file info', e, s);
      return <FileInfoFaceWidget>[];
    }
  }
}

enum NoFacesReason {
  fileNotUploaded,
  fileNotAnalyzed,
  noFacesFound,
  faceThumbnailGenerationFailed,
}

String getNoFaceReasonText(
  BuildContext context,
  NoFacesReason reason,
) {
  switch (reason) {
    case NoFacesReason.fileNotUploaded:
      return S.of(context).fileNotUploadedYet;
    case NoFacesReason.fileNotAnalyzed:
      return S.of(context).imageNotAnalyzed;
    case NoFacesReason.noFacesFound:
      return S.of(context).noFacesFound;
    case NoFacesReason.faceThumbnailGenerationFailed:
      return "Unable to generate face thumbnails";
  }
}

class NoFaceChipButtonWidget extends StatelessWidget {
  final NoFacesReason reason;

  const NoFaceChipButtonWidget(
    this.reason, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: ChipButtonWidget(
        getNoFaceReasonText(context, reason),
        noChips: true,
      ),
    );
  }
}
