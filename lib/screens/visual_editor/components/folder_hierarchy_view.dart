import 'package:music_app/constants.dart';
import 'package:flutter/material.dart';

class FolderHierarchyView<T, F> extends StatelessWidget {
  // Folder Path Config
  final List<F> currentPath;
  final F? currentFolder;
  final String Function(F) getFolderId;
  final String Function(F) getFolderName;
  final String rootName;
  
  // List Items Config
  final List<T> items;
  final T? selectedItem;
  final bool Function(T) isItemFolder;
  final dynamic Function(T) getItemId;
  final Widget Function(T) buildItemName;
  final String? Function(T)? getItemSubtitle;
  final Color Function(T)? getItemColor;
  final bool Function(T) isItemSelected;
  final Widget? Function(T)? getItemLeading;
  final Widget? Function(T)? getItemTrailing;

  // Interactions
  final void Function(F?) onNavigateToFolder;
  final void Function(T) onNavigateToItemFolder;
  final void Function(T) onSelectItem;
  final void Function(dynamic draggedItemId, dynamic targetFolderId)? onMoveItem;
  final void Function(int oldIndex, int newIndex)? onReorder;

  // View State
  final bool isLoading;
  final Widget? loadingWidget;
  final Widget? emptyWidget;

  const FolderHierarchyView({
    super.key,
    required this.currentPath,
    this.currentFolder,
    required this.getFolderId,
    required this.getFolderName,
    this.rootName = 'Root Folder',
    required this.items,
    this.selectedItem,
    required this.isItemFolder,
    required this.getItemId,
    required this.buildItemName,
    this.getItemSubtitle,
    this.getItemColor,
    required this.isItemSelected,
    this.getItemLeading,
    this.getItemTrailing,
    required this.onNavigateToFolder,
    required this.onNavigateToItemFolder,
    required this.onSelectItem,
    this.onMoveItem,
    this.onReorder,
    this.isLoading = false,
    this.loadingWidget,
    this.emptyWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Breadcrumb Top Section
        Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxHeight: 400),
          color: const Color(0xFF191919),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildBreadcrumbDropTarget(
                  context,
                  targetId: null,
                  onAccept: (id) => onMoveItem?.call(id, null),
                  isSelected: currentFolder == null,
                  child: InkWell(
                    onTap: () => onNavigateToFolder(null),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: currentFolder == null && selectedItem == null ? AppColors.accent.withOpacity(0.1) : AppColors.overlaySubtle,
                        borderRadius: BorderRadius.circular(4)
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.home, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 8),
                          Text(rootName, style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.bold))
                        ]
                      ),
                    )
                  )
                ),
                for (var i = 0; i < currentPath.length; i++)
                  Padding(
                    padding: EdgeInsets.only(left: 16.0 + (i * 12.0), top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.subdirectory_arrow_right, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        _buildBreadcrumbDropTarget(
                          context,
                          targetId: getFolderId(currentPath[i]),
                          onAccept: (id) => onMoveItem?.call(id, getFolderId(currentPath[i])),
                          isSelected: currentFolder != null && getFolderId(currentPath[i]) == getFolderId(currentFolder as F),
                          child: InkWell(
                            onTap: () => onNavigateToFolder(currentPath[i]),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: (currentFolder != null && getFolderId(currentPath[i]) == getFolderId(currentFolder as F) && selectedItem == null) ? AppColors.accent.withOpacity(0.1) : AppColors.overlaySubtle,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(getFolderName(currentPath[i]), style: TextStyle(
                                  color: (currentFolder != null && getFolderId(currentPath[i]) == getFolderId(currentFolder as F) && selectedItem == null) ? AppColors.accent : AppColors.textSecondary, 
                                  fontSize: 13, fontWeight: FontWeight.bold))
                            )
                          )
                        )
                      ]
                    )
                  ),
                if (selectedItem != null && !isItemFolder(selectedItem as T))
                  Padding(
                    padding: EdgeInsets.only(left: 16.0 + (currentPath.length * 12.0), top: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.subdirectory_arrow_right, size: 16, color: AppColors.accent),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.accent.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              getItemLeading?.call(selectedItem as T) ?? Icon(Icons.insert_drive_file, size: 14, color: AppColors.accent),
                              const SizedBox(width: 6),
                              buildItemName(selectedItem as T),
                            ],
                          )
                        )
                      ]
                    )
                  )
              ]
            )
          )
        ),
        
        // Custom Area
        if (loadingWidget != null && isLoading)
           loadingWidget!,

        // List View
        Expanded(
          child: isLoading && items.isEmpty 
            ? const Center(child: CircularProgressIndicator())
            : items.isEmpty
              ? (emptyWidget ?? Center(child: Text('Bucket is empty.', style: TextStyle(color: AppColors.textSecondary))))
              : _buildList()
        ),
      ],
    );
  }

  Widget _buildBreadcrumbDropTarget(BuildContext context, {
    required dynamic targetId,
    required void Function(dynamic id) onAccept,
    required bool isSelected,
    required Widget child
  }) {
      if (onMoveItem == null) return child;

      return DragTarget<Object>(
        onWillAcceptWithDetails: (details) => details.data != targetId,
        onAcceptWithDetails: (details) => onAccept(details.data),
        builder: (context, candidateData, rejectedData) {
           if (candidateData.isNotEmpty) {
             return Container(
               decoration: BoxDecoration(
                 color: AppColors.accent.withOpacity(0.3),
                 borderRadius: BorderRadius.circular(4),
                 border: Border.all(color: AppColors.accent, width: 2)
               ),
               child: child,
             );
           }
           return child;
        }
      );
  }

  Widget _buildList() {
    if (onReorder != null) {
       return ReorderableListView.builder(
          itemCount: items.length,
          onReorder: onReorder!,
          itemBuilder: (context, index) => _buildListItem(context, items[index], index)
       );
    } else {
       return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) => _buildListItem(context, items[index], index)
       );
    }
  }

  Widget _buildListItem(BuildContext context, T item, int index) {
     final bool isSelected = isItemSelected(item);
     final bool folder = isItemFolder(item);
     final itemId = getItemId(item);
     final Color color = getItemColor?.call(item) ?? (folder ? Colors.amberAccent : AppColors.accent);

     Widget itemWidget = InkWell(
        onTap: () {
            onSelectItem(item);
        },
        onDoubleTap: () {
            if (folder) onNavigateToItemFolder(item);
        },
        child: Container(
           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
           decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF37373D) : Colors.transparent,
              border: Border(left: BorderSide(
                 color: isSelected ? color : Colors.transparent, width: 4
              ))
           ),
           child: Row(
              children: [
                 if (getItemLeading != null) 
                    getItemLeading!(item)!
                 else
                    Icon(folder ? Icons.folder : Icons.insert_drive_file, color: color, size: 20),
                 
                 const SizedBox(width: 12),
                 Expanded(
                    child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          buildItemName(item),
                          if (getItemSubtitle != null && getItemSubtitle!(item) != null) ...[
                             const SizedBox(height: 4),
                             Text(getItemSubtitle!(item)!, style: TextStyle(color: AppColors.textSecondary, fontSize: 10)),
                          ]
                       ],
                    )
                 ),
                 
                 if (getItemTrailing != null) getItemTrailing!(item)!,
                 if (onReorder != null && !folder)
                    ReorderableDragStartListener(
                       index: index,
                       child: Padding(padding: EdgeInsets.only(left: 8.0), child: Icon(Icons.drag_indicator, color: AppColors.borderSubtle, size: 20))
                    )
              ]
           )
        )
     );

     if (onMoveItem == null) {
        return Container(key: ValueKey(itemId), child: itemWidget);
     }

     Widget dropTargetWidget = itemWidget;
     if (folder) {
        dropTargetWidget = DragTarget<Object>(
           onWillAcceptWithDetails: (details) => details.data != itemId,
           onAcceptWithDetails: (details) => onMoveItem!(details.data, itemId),
           builder: (context, candidateData, rejectedData) {
              if (candidateData.isNotEmpty) {
                 return Container(
                    decoration: BoxDecoration(
                       color: color.withOpacity(0.3),
                       border: Border.all(color: color, width: 2),
                       borderRadius: BorderRadius.circular(4)
                    ),
                    child: itemWidget
                 );
              }
              return itemWidget;
           }
        );
     }

     return Container(
        key: ValueKey(itemId),
        child: LongPressDraggable<Object>(
           data: itemId,
           feedback: Material(
              color: Colors.transparent,
              child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                 decoration: BoxDecoration(color: color.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
                 child: buildItemName(item)
              )
           ),
           childWhenDragging: Opacity(opacity: 0.3, child: itemWidget),
           child: dropTargetWidget
        )
     );
  }
}
