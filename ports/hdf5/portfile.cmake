vcpkg_fail_port_install(ON_TARGET "UWP")

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO  HDFGroup/hdf5
    REF hdf5-1_12_0
    SHA512 "d84df1ea72dc6fa038440a370e1b1ff523364474e7f214b967edc26d3191b2ef4fe1d9273c4a086a5945f1ad1ab6aa8dbcda495898e7967b2b73fd93dd5071e0"
    HEAD_REF develop
    PATCHES
        hdf5_config.patch
        szip.patch
        mingw-import-libs.patch
        pkgconfig-requires.patch
        pkgconfig-link-order.patch
)

if("parallel" IN_LIST FEATURES AND "cpp" IN_LIST FEATURES)
    message(FATAL_ERROR "Feature Parallel and C++ options are mutually exclusive.")
endif()

if("fortran" IN_LIST FEATURE)
    message(WARNING "Fortran is not yet official supported within VCPKG. Build will most likly fail if ninja 1.10 and a Fortran compiler are not available.")
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        parallel     HDF5_ENABLE_PARALLEL
        tools        HDF5_BUILD_TOOLS
        cpp          HDF5_BUILD_CPP_LIB
        szip         HDF5_ENABLE_SZIP_SUPPORT
        szip         HDF5_ENABLE_SZIP_ENCODING
        zlib         HDF5_ENABLE_Z_LIB_SUPPORT
        fortran      HDF5_BUILD_FORTRAN
        threadsafe   HDF5_ENABLE_THREADSAFE
)

file(REMOVE "${SOURCE_PATH}/config/cmake_ext_mod/FindSZIP.cmake") # Outdated; does not find debug szip

if(FEATURES MATCHES "tools" AND VCPKG_CRT_LINKAGE STREQUAL "static")
    list(APPEND FEATURE_OPTIONS -DBUILD_STATIC_EXECS=ON)
endif()

if(NOT VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    list(APPEND FEATURE_OPTIONS
                    -DBUILD_STATIC_LIBS=OFF
                    -DONLY_SHARED_LIBS=ON)
endif()

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    DISABLE_PARALLEL_CONFIGURE
    PREFER_NINJA
    OPTIONS
        ${FEATURE_OPTIONS}
        -DBUILD_TESTING=OFF
        -DHDF5_BUILD_EXAMPLES=OFF
        -DHDF5_INSTALL_DATA_DIR=share/hdf5/data
        -DHDF5_INSTALL_CMAKE_DIR=share
        -DHDF_PACKAGE_NAMESPACE:STRING=hdf5::
)

vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(READ "${CURRENT_PACKAGES_DIR}/share/hdf5/hdf5-config.cmake" contents)
string(REPLACE [[${HDF5_PACKAGE_NAME}_TOOLS_DIR "${PACKAGE_PREFIX_DIR}/bin"]] [[${HDF5_PACKAGE_NAME}_TOOLS_DIR "${PACKAGE_PREFIX_DIR}/tools/hdf5"]] contents ${contents})
file(WRITE "${CURRENT_PACKAGES_DIR}/share/hdf5/hdf5-config.cmake" ${contents})

if(FEATURES MATCHES "tools")
    set(TOOLS h5cc h5hlcc h5c++ h5hlc++ h5copy h5diff h5dump h5ls h5stat gif2h5 h52gif h5clear h5debug h5format_convert h5jam h5unjam h5ls h5mkgrp h5repack h5repart h5watch ph5diff h5import)
    if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
        set(TOOL_SUFFIXES "-shared${VCPKG_TARGET_EXECUTABLE_SUFFIX};${VCPKG_TARGET_EXECUTABLE_SUFFIX}")
    else()
        set(TOOL_SUFFIXES "-static${VCPKG_TARGET_EXECUTABLE_SUFFIX};${VCPKG_TARGET_EXECUTABLE_SUFFIX}")
    endif()

    foreach(tool IN LISTS TOOLS)
        foreach(suffix IN LISTS TOOL_SUFFIXES)
            if(EXISTS "${CURRENT_PACKAGES_DIR}/debug/bin/${tool}${suffix}")
                file(REMOVE "${CURRENT_PACKAGES_DIR}/debug/bin/${tool}${suffix}")
            endif()
            if(EXISTS "${CURRENT_PACKAGES_DIR}/bin/${tool}${suffix}")
                file(INSTALL "${CURRENT_PACKAGES_DIR}/bin/${tool}${suffix}"
                     DESTINATION "${CURRENT_PACKAGES_DIR}/tools/${PORT}")
                file(REMOVE "${CURRENT_PACKAGES_DIR}/bin/${tool}${suffix}")
            endif()
        endforeach()
    endforeach()
    vcpkg_copy_tool_dependencies("${CURRENT_PACKAGES_DIR}/tools/${PORT}")
endif()

if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/bin" "${CURRENT_PACKAGES_DIR}/debug/bin")
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/lib/pkgconfig")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/lib/pkgconfig")

file(RENAME "${CURRENT_PACKAGES_DIR}/share/${PORT}/data/COPYING" "${CURRENT_PACKAGES_DIR}/share/${PORT}/copyright")
configure_file("${CMAKE_CURRENT_LIST_DIR}/vcpkg-cmake-wrapper.cmake" "${CURRENT_PACKAGES_DIR}/share/${PORT}/vcpkg-cmake-wrapper.cmake" @ONLY)
