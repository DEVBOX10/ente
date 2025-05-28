/**
 * @file code that really belongs to pages/gallery.tsx itself (or related
 * files), but it written here in a separate file so that we can write in this
 * package that has TypeScript strict mode enabled.
 *
 * Once the original gallery.tsx is strict mode, this code can be inlined back
 * there.
 */

import { Paper, Stack, Typography } from "@mui/material";
import { CenteredFill } from "ente-base/components/containers";
import type { SearchSuggestion } from "ente-new/photos/services/search/types";
import { t } from "i18next";
import React, { useState } from "react";
import { enableML } from "../../services/ml";
import { EnableML, FaceConsent } from "../sidebar/MLSettings";
import { useMLStatusSnapshot } from "../utils/use-snapshot";
import { useWrapAsyncOperation } from "../utils/use-wrap-async";
import { GalleryItemsHeaderAdapter, GalleryItemsSummary } from "./ListHeader";

/**
 * The context in which a selection was made.
 *
 * This allows us to reset the selection if user moves to a different context
 * and starts a new selection.
 * */
export type SelectionContext =
    | { mode: "albums" | "hidden-albums"; collectionID: number }
    | { mode: "people"; personID: string };

interface SearchResultsHeaderProps {
    searchSuggestion: SearchSuggestion;
    fileCount: number;
}

export const SearchResultsHeader: React.FC<SearchResultsHeaderProps> = ({
    searchSuggestion,
    fileCount,
}) => (
    <GalleryItemsHeaderAdapter>
        <Typography
            variant="h6"
            sx={{ fontWeight: "regular", color: "text.muted" }}
        >
            {t("search_results")}
        </Typography>
        <GalleryItemsSummary
            name={searchSuggestion.label}
            fileCount={fileCount}
        />
    </GalleryItemsHeaderAdapter>
);

import AddPhotoAlternateIcon from "@mui/icons-material/AddPhotoAlternateOutlined";
import FolderIcon from "@mui/icons-material/FolderOutlined";
import { Button, styled } from "@mui/material";
import { EnteLogo } from "ente-base/components/EnteLogo";
import {
    FlexWrapper,
    VerticallyCentered,
} from "ente-shared/components/Container";
import { Trans } from "react-i18next";

// eslint-disable-next-line @typescript-eslint/ban-ts-comment
// @ts-ignore
export function GalleryEmptyState({ openUploader, shouldAllowNewUpload }) {
    return (
        <Wrapper>
            <Stack sx={{ flex: "none", paddingBlock: "12px 32px" }}>
                <VerticallyCentered sx={{ flex: "none" }}>
                    <Typography
                        variant="h3"
                        sx={{
                            color: "text.muted",
                            userSelect: "none",
                            marginBlockEnd: 1,
                            svg: {
                                color: "text.base",
                                verticalAlign: "middle",
                                marginBlockEnd: "2px",
                            },
                        }}
                    >
                        <Trans
                            i18nKey="welcome_to_ente_title"
                            components={{ a: <EnteLogo /> }}
                        />
                    </Typography>
                    <Typography variant="h2">
                        {t("welcome_to_ente_subtitle")}
                    </Typography>
                </VerticallyCentered>
            </Stack>
            <NonDraggableImage
                height={287.57}
                alt=""
                src="/images/empty-state/ente_duck.png"
                srcSet="/images/empty-state/ente_duck@2x.png, /images/empty-state/ente_duck@3x.png"
            />
            <VerticallyCentered paddingTop={1.5} paddingBottom={1.5}>
                <Button
                    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
                    // @ts-ignore
                    style={{ cursor: !shouldAllowNewUpload && "not-allowed" }}
                    color="accent"
                    // eslint-disable-next-line @typescript-eslint/no-unsafe-return, @typescript-eslint/no-unsafe-call
                    onClick={() => openUploader("upload")}
                    disabled={!shouldAllowNewUpload}
                    sx={{ mt: 1.5, p: 1, width: 320, borderRadius: 0.5 }}
                >
                    <FlexWrapper sx={{ gap: 1 }} justifyContent="center">
                        <AddPhotoAlternateIcon />
                        {t("upload_first_photo")}
                    </FlexWrapper>
                </Button>
                <Button
                    // eslint-disable-next-line @typescript-eslint/ban-ts-comment
                    // @ts-ignore
                    style={{ cursor: !shouldAllowNewUpload && "not-allowed" }}
                    // eslint-disable-next-line @typescript-eslint/no-unsafe-return, @typescript-eslint/no-unsafe-call
                    onClick={() => openUploader("import")}
                    disabled={!shouldAllowNewUpload}
                    sx={{ mt: 1.5, p: 1, width: 320, borderRadius: 0.5 }}
                >
                    <FlexWrapper sx={{ gap: 1 }} justifyContent="center">
                        <FolderIcon />
                        {t("import_your_folders")}
                    </FlexWrapper>
                </Button>
            </VerticallyCentered>
        </Wrapper>
    );
}

const Wrapper = styled("div")`
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
`;

/**
 * Prevent the image from being selected _and_ dragged, since dragging it
 * triggers the our dropdown selector overlay.
 */
const NonDraggableImage = styled("img")`
    pointer-events: none;
    user-select: none;
`;

export const PeopleEmptyState: React.FC = () => {
    const mlStatus = useMLStatusSnapshot();

    switch (mlStatus?.phase) {
        case "disabled":
            return <PeopleEmptyStateDisabled />;
        case "done":
            return (
                <PeopleEmptyStateMessage>
                    {t("people_empty_too_few")}
                </PeopleEmptyStateMessage>
            );
        default:
            return (
                <PeopleEmptyStateMessage>
                    {t("syncing_wait")}
                </PeopleEmptyStateMessage>
            );
    }
};

export const PeopleEmptyStateMessage: React.FC<React.PropsWithChildren> = ({
    children,
}) => (
    <CenteredFill>
        <Typography
            sx={{
                color: "text.muted",
                mx: 1,
                // Approximately compensate for the hidden section bar (86px),
                // and then add a bit extra padding so that the message appears
                // visually off the center, towards the top.
                paddingBlockEnd: "126px",
            }}
        >
            {children}
        </Typography>
    </CenteredFill>
);

export const PeopleEmptyStateDisabled: React.FC = () => {
    const [showConsent, setShowConsent] = useState(false);

    const handleConsent = useWrapAsyncOperation(async () => {
        await enableML();
    });

    return (
        <Stack sx={{ alignItems: "center", flex: 1, overflow: "auto" }}>
            <Paper
                // Top margin is to prevent clipping of the shadow.
                sx={{ maxWidth: "390px", padding: "4px", mt: 1, mb: "2rem" }}
            >
                {!showConsent ? (
                    <EnableML onEnable={() => setShowConsent(true)} />
                ) : (
                    <FaceConsent
                        onConsent={handleConsent}
                        onCancel={() => setShowConsent(false)}
                    />
                )}
            </Paper>
        </Stack>
    );
};
