module components.assetanimation;
import core.properties;
import components.icomponent;
import utility.output;

import derelict.assimp3.assimp;
import gl3n.linalg;

shared class AssetAnimation
{
private:
    shared AnimationSet _animationSet;
    shared int _numberOfBones;
	shared mat4 _inverseTransform;

public:
    mixin( Property!_animationSet );
    mixin( Property!_numberOfBones );
	mixin( Property!_inverseTransform );

    this( const(aiAnimation*) animation, const(aiMesh*) mesh, const(aiNode*) boneHierarchy )
    {
        _animationSet.duration = cast(float)animation.mDuration;
        _animationSet.fps = cast(float)animation.mTicksPerSecond;
		_inverseTransform = convertAIMatrix(boneHierarchy.mChildren[ 1 ].mTransformation);
		//_inverseTransform = _inverseTransform.inverse();

		log( OutputType.Warning, "Node Transform: ", _inverseTransform[0][0], " ", _inverseTransform[0][1], " ", _inverseTransform[0][2], " ", _inverseTransform[0][3] );
		log( OutputType.Warning, "Node Transform: ", _inverseTransform[1][0], " ", _inverseTransform[1][1], " ", _inverseTransform[1][2], " ", _inverseTransform[1][3] );
		log( OutputType.Warning, "Node Transform: ", _inverseTransform[2][0], " ", _inverseTransform[2][1], " ", _inverseTransform[2][2], " ", _inverseTransform[2][3] );
		log( OutputType.Warning, "Node Transform: ", _inverseTransform[3][0], " ", _inverseTransform[3][1], " ", _inverseTransform[3][2], " ", _inverseTransform[3][3] );

        _animationSet.animNodes = makeNodesFromNode( animation, mesh, boneHierarchy.mChildren[ 1 ], null );

        //Node temp = _animationSet.animNodes;
        //Node temp2 = _animationSet.animNodes.children[ 0 ];
        //Node temp3 = _animationSet.animNodes.children[ 0 ].children[ 0 ];
    }

    // Each bone has one of two setups:
    // Split up into five seperate nodes (translation -> preRotation -> Rotation -> Scale -> Bone)
    // Or the bone is one node in the hierarchy
    shared(Node) makeNodesFromNode( const(aiAnimation*) animation, const(aiMesh*) mesh, const(aiNode*) currNode, shared Node returnNode )
    { 
        string name = cast(string)currNode.mName.data[ 0 .. currNode.mName.length ];
        int id = findNodeWithName( name, mesh );
        shared Node node;
        // If the node is the translation segment of a bone add bone based on all of its parts (the next couple of children nodes)
        // Else if the node is another segment of a bone add its data to the partial bone (the parent node)
        // Else if the node is a full bone add it

		log( OutputType.Warning, "Node Transform: ", currNode.mTransformation.a1, " ", currNode.mTransformation.a2, " ", currNode.mTransformation.a3, " ", currNode.mTransformation.a4 );
		log( OutputType.Warning, "Node Transform: ", currNode.mTransformation.b1, " ", currNode.mTransformation.b2, " ", currNode.mTransformation.b3, " ", currNode.mTransformation.b4 );
		log( OutputType.Warning, "Node Transform: ", currNode.mTransformation.c1, " ", currNode.mTransformation.c2, " ", currNode.mTransformation.c3, " ", currNode.mTransformation.c4 );
		log( OutputType.Warning, "Node Transform: ", currNode.mTransformation.d1, " ", currNode.mTransformation.d2, " ", currNode.mTransformation.d3, " ", currNode.mTransformation.d4 );

        if( id != -1 )
        {
			log( OutputType.Warning, "Animation Node ");
            node = new shared Node( name );
            node.id = id;
            node.transform = convertAIMatrix( mesh.mBones[ node.id ].mOffsetMatrix );

			//log( OutputType.Warning, "Node Transform: ", node.transform[0][0], " ", node.transform[0][1], " ", node.transform[0][2], " ", node.transform[0][3] );
			//log( OutputType.Warning, "Node Transform: ", node.transform[1][0], " ", node.transform[1][1], " ", node.transform[1][2], " ", node.transform[1][3] );
			//log( OutputType.Warning, "Node Transform: ", node.transform[2][0], " ", node.transform[2][1], " ", node.transform[2][2], " ", node.transform[2][3] );
			//log( OutputType.Warning, "Node Transform: ", node.transform[3][0], " ", node.transform[3][1], " ", node.transform[3][2], " ", node.transform[3][3] );
			//aiMatrix4x4 matrix = mesh.mBones[ node.id ].mOffsetMatrix;
			//log( OutputType.Warning, "Node Transform: ", matrix.a1, " ", matrix.a2, " ", matrix.a3, " ", matrix.a4 );
			//log( OutputType.Warning, "Node Transform: ", matrix.b1, " ", matrix.b2, " ", matrix.b3, " ", matrix.b4 );
			//log( OutputType.Warning, "Node Transform: ", matrix.c1, " ", matrix.c2, " ", matrix.c3, " ", matrix.c4 );
			//log( OutputType.Warning, "Node Transform: ", matrix.d1, " ", matrix.d2, " ", matrix.d3, " ", matrix.d4 );
			
            assignAnimationData( animation, node );

            returnNode = node;
            _numberOfBones++;
        }
        else
        {
            node = returnNode;
        }

        // For each child node
        for( int i = 0; i < currNode.mNumChildren; i++ )
        {
            // Create it and assign to this node as a child
            if( id != -1 )
                node.children ~= makeNodesFromNode( animation, mesh, currNode.mChildren[ i ], node );
            else
                return makeNodesFromNode( animation, mesh, currNode.mChildren[ i ], node );
        }

        return node;
    }

    void assignAnimationData( const(aiAnimation*) animation, shared Node nodeToAssign )
    {
        // For each bone animation data
        for( int i = 0; i < animation.mNumChannels; i++)
        {
            const(aiNodeAnim*) temp = animation.mChannels[ i ];
            string name = cast(string)animation.mChannels[ i ].mNodeName.data[ 0 .. animation.mChannels[ i ].mNodeName.length ];
            // If the names match
            if( checkEnd(name, "_$AssimpFbx$_Translation" ) && name[ 0 .. (animation.mChannels[ i ].mNodeName.length - 24) ] == nodeToAssign.name )
            {
                nodeToAssign.positionKeys = convertVectorArray( animation.mChannels[ i ].mPositionKeys,
                                                                animation.mChannels[ i ].mNumPositionKeys );
            }
            else if( checkEnd(name, "_$AssimpFbx$_Rotation" ) && name[ 0 .. animation.mChannels[ i ].mNodeName.length - 21 ] == nodeToAssign.name )
            {
                nodeToAssign.rotationKeys = convertQuat( animation.mChannels[ i ].mRotationKeys,
                                                         animation.mChannels[ i ].mNumRotationKeys );
            }
            else if( checkEnd(name, "_$AssimpFbx$_Scaling" ) && name[ 0 .. animation.mChannels[ i ].mNodeName.length - 20 ] == nodeToAssign.name )
            {
                nodeToAssign.scaleKeys = convertVectorArray( animation.mChannels[ i ].mScalingKeys,
                                                             animation.mChannels[ i ].mNumScalingKeys );
            }
            else if( name == nodeToAssign.name )
            {
                // Assign the bone animation data to the bone
                nodeToAssign.positionKeys = convertVectorArray( animation.mChannels[ i ].mPositionKeys,
                                                                animation.mChannels[ i ].mNumPositionKeys );

                nodeToAssign.scaleKeys = convertVectorArray( animation.mChannels[ i ].mScalingKeys,
                                                             animation.mChannels[ i ].mNumScalingKeys );

                nodeToAssign.rotationKeys = convertQuat( animation.mChannels[ i ].mRotationKeys,
                                                         animation.mChannels[ i ].mNumRotationKeys );               
            }
        }
    }
    // aiVectorKey[] to vec3[]
    shared( vec3[] ) convertVectorArray( const(aiVectorKey*) vectors, int numKeys )
    {
        shared vec3[] keys;
        for( int i = 0; i < numKeys; i++ )
        {
            aiVector3D vector = vectors[ i ].mValue;
            keys ~= vec3( vector.x, vector.y, vector.z );
        }

        return keys;
    }
    // aiQuatKey[] to quat[]
    shared( quat[] ) convertQuat( const(aiQuatKey*) quaternions, int numKeys )
    {
        shared quat[] keys;
        for( int i = 0; i < numKeys; i++ )
        {
            aiQuatKey quaternion = quaternions[ i ];
            keys ~= quat( quaternion.mValue.w, quaternion.mValue.x, quaternion.mValue.y, quaternion.mValue.z );
            int ii = 0;
        }

        return keys;
    }
    
    // Find bone with name in our structure
    int findNodeWithName( string name, const(aiMesh*) mesh )
    {
        for( int i = 0; i < mesh.mNumBones; i++ )
        {
            if( name == cast(string)mesh.mBones[ i ].mName.data[ 0 .. mesh.mBones[ i ].mName.length ] )
            {
                return i;
            }
        }

        return -1;
    }
    // Check if string stringToTest ends with string end
    bool checkEnd( string stringToTest, string end )
    {
        if( stringToTest.length > end.length )
        {
            string temp = stringToTest[ (stringToTest.length - end.length) .. stringToTest.length ];

            if( stringToTest[ (stringToTest.length - end.length) .. stringToTest.length ] == end )
            {
                return true;
            }
        }

        return false;
    }

    shared( mat4[] ) getTransformsAtTime( shared float time )
    {
        shared mat4[] boneTransforms = new shared mat4[ _numberOfBones ];

        // Check shader/model
        for( int i = 0; i < _numberOfBones; i++)
        {
            boneTransforms[ i ] = mat4.identity;
        }

        fillTransforms( boneTransforms, _animationSet.animNodes, time, mat4.identity, 0 );
		
        //mat4 temp = boneTransforms[ 0 ];
        //mat4 temp2 = boneTransforms[ 1 ];
        //mat4 temp3 = boneTransforms[ 2 ];

        return boneTransforms;
    }

    void fillTransforms( shared mat4[] transforms, shared Node node, shared float time, shared mat4 parentTransform, int boneNum)
    {
        // Calculate matrix based on node.bone data and time
        /*shared mat4 finalTransform;
        shared mat4 boneTransform = mat4.identity;
        shared quat temp = quat( 0.0f, 0.707106f, -0.707106f, 0.0f );
		shared mat4 test = mat4(0.0f, 1.0f, 0.0f, 0.0f, -1.0f, 0.0f, 0.0f, 32.7f, 0.0f, 0.0f, 1.0f, 0.02f, 0.0f, 0.0f, 0.0f, 1.0f);
		shared mat4 test2 = mat4(0.978468f, 0.0f, -0.2064f, 12.2843f, 0.0f, 1.0f, 0.0f, 0.0f, 0.2064f, 0.0f, 0.978468f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f);
		shared mat4 test3 = mat4(0.0f, -0.977f,  0.212f, 16.632f, 1.0f,  0.0f,  0.0f,  0.0f, 0.0f,  0.212f,  0.977f,  0.0f, 0.0f,  0.0f,  0.0f,  1.0f);
		
		if( node.positionKeys.length > cast(int)time )
            //boneTransform.translation( node.positionKeys[ cast(int)time ].vector[ 0 ], node.positionKeys[ cast(int)time ].vector[ 1 ], node.positionKeys[ cast(int)time ].vector[ 2 ] );
		if( node.rotationKeys.length > cast(int)time )
			boneTransform = boneTransform * node.rotationKeys[ cast(int)time ].to_matrix!( 4, 4 );
		if( node.scaleKeys.length > cast(int)time )
            //boneTransform.scale( node.scaleKeys[ cast(int)time ].vector[ 0 ], node.scaleKeys[ cast(int)time ].vector[ 1 ], node.scaleKeys[ cast(int)time ].vector[ 2 ] );
        
		
		// ASSIMP SKELETAL ANIMATION TUTORIAL HAS A GLOBAL INVERSE TRANSFORM, CHECK IF CAUSING ISSUES
		// CHECK TO SEE IF WEIRD EXTRA ASSIMP NODES CONTAIN NEEDED DATA
		if(boneNum == 0)
		{
			finalTransform = (test * parentTransform) * boneTransform;
			transforms[ node.id ] = finalTransform * node.transform;
		}
		if(boneNum == 1)
		{
			finalTransform = boneTransform * parentTransform;
			transforms[ node.id ] = finalTransform * node.transform;
		}
		if(boneNum == 2)
		{
			finalTransform = (test3 * parentTransform) * boneTransform;
			transforms[ node.id ] = finalTransform * node.transform;
		}
		if(boneNum == 0)
		{
			finalTransform = (test * parentTransform) * boneTransform;
			transforms[ node.id ] = finalTransform * node.transform;
		}
		if(boneNum == 1)
		{
			finalTransform = (test2 * parentTransform) * boneTransform;
			transforms[ node.id ] = finalTransform * node.transform;
		}
		if(boneNum == 2)
		{
			finalTransform = (test3 * parentTransform) * boneTransform;
			transforms[ node.id ] = finalTransform * node.transform;
		}
		boneNum++;

		log( OutputType.Warning, "Node Transform: ", transforms[ node.id ][0][0], " ", transforms[ node.id ][0][1], " ", transforms[ node.id ][0][2], " ", transforms[ node.id ][0][3] );
		log( OutputType.Warning, "Node Transform: ", transforms[ node.id ][1][0], " ", transforms[ node.id ][1][1], " ", transforms[ node.id ][1][2], " ", transforms[ node.id ][1][3] );
		log( OutputType.Warning, "Node Transform: ", transforms[ node.id ][2][0], " ", transforms[ node.id ][2][1], " ", transforms[ node.id ][2][2], " ", transforms[ node.id ][2][3] );
		log( OutputType.Warning, "Node Transform: ", transforms[ node.id ][3][0], " ", transforms[ node.id ][3][1], " ", transforms[ node.id ][3][2], " ", transforms[ node.id ][3][3] );

        // Store the transform in the correct place and check children
        for( int i = 0; i < node.children.length; i++ )
        {
            fillTransforms( transforms, node.children[ i ], time, finalTransform, boneNum );
        }*/

		// Calculate matrix based on node.bone data and time
		shared mat4 finalTransform;
		shared mat4 boneTransform = mat4.identity;
		shared quat temp = quat( 0.0f, 0.707106f, -0.707106f, 0.0f );

		if( node.scaleKeys.length > cast(int)time )
			boneTransform = boneTransform * boneTransform.scale( node.scaleKeys[ cast(int)time ].vector[ 0 ], node.scaleKeys[ cast(int)time ].vector[ 1 ], node.scaleKeys[ cast(int)time ].vector[ 2 ] );
		if( node.rotationKeys.length > cast(int)time )
			boneTransform = boneTransform * node.rotationKeys[ cast(int)time ].to_matrix!( 4, 4 );
		if( node.positionKeys.length > cast(int)time )
		{
			boneTransform = boneTransform * boneTransform.translation( node.positionKeys[ cast(int)time ].vector[ 0 ], node.positionKeys[ cast(int)time ].vector[ 1 ], node.positionKeys[ cast(int)time ].vector[ 2 ] );
		}

		finalTransform = parentTransform * boneTransform;
 		transforms[ node.id ] = finalTransform * node.transform;

		if(time == 0.002f)
		{
			log( OutputType.Warning, node.positionKeys[ cast(int)time ].vector[ 1 ] );
			log( OutputType.Warning, "Bone Transform" );
			log( OutputType.Warning, boneTransform[0][0], " ", boneTransform[0][1], " ", boneTransform[0][2], " ", boneTransform[0][3] );
			log( OutputType.Warning, boneTransform[1][0], " ", boneTransform[1][1], " ", boneTransform[1][2], " ", boneTransform[1][3] );
			log( OutputType.Warning, boneTransform[2][0], " ", boneTransform[2][1], " ", boneTransform[2][2], " ", boneTransform[2][3] );
			log( OutputType.Warning, boneTransform[3][0], " ", boneTransform[3][1], " ", boneTransform[3][2], " ", boneTransform[3][3] );
			log( OutputType.Warning, "Node Offset" );
			log( OutputType.Warning, node.transform[0][0], " ", node.transform[0][1], " ", node.transform[0][2], " ", node.transform[0][3] );
			log( OutputType.Warning, node.transform[1][0], " ", node.transform[1][1], " ", node.transform[1][2], " ", node.transform[1][3] );
			log( OutputType.Warning, node.transform[2][0], " ", node.transform[2][1], " ", node.transform[2][2], " ", node.transform[2][3] );
			log( OutputType.Warning, node.transform[3][0], " ", node.transform[3][1], " ", node.transform[3][2], " ", node.transform[3][3] );
			log( OutputType.Warning, "Final Matrix" );
			log( OutputType.Warning, transforms[ node.id ][0][0], " ", transforms[ node.id ][0][1], " ", transforms[ node.id ][0][2], " ", transforms[ node.id ][0][3] );
			log( OutputType.Warning, transforms[ node.id ][1][0], " ", transforms[ node.id ][1][1], " ", transforms[ node.id ][1][2], " ", transforms[ node.id ][1][3] );
			log( OutputType.Warning, transforms[ node.id ][2][0], " ", transforms[ node.id ][2][1], " ", transforms[ node.id ][2][2], " ", transforms[ node.id ][2][3] );
			log( OutputType.Warning, transforms[ node.id ][3][0], " ", transforms[ node.id ][3][1], " ", transforms[ node.id ][3][2], " ", transforms[ node.id ][3][3] );
		}

		// Store the transform in the correct place and check children
		for( int i = 0; i < node.children.length; i++ )
		{
			fillTransforms( transforms, node.children[ i ], time, finalTransform, 0 );
		}
    }

    mat4 convertAIMatrix( aiMatrix4x4 aiMatrix )
    {
        mat4 matrix = mat4.identity;

        matrix[0][0] = aiMatrix.a1;
        matrix[0][1] = aiMatrix.a2;
        matrix[0][2] = aiMatrix.a3;
        matrix[0][3] = aiMatrix.a4;
        matrix[1][0] = aiMatrix.b1;
        matrix[1][1] = aiMatrix.b2;
        matrix[1][2] = aiMatrix.b3;
        matrix[1][3] = aiMatrix.b4;
        matrix[2][0] = aiMatrix.c1;
        matrix[2][1] = aiMatrix.c2;
        matrix[2][2] = aiMatrix.c3;
        matrix[2][3] = aiMatrix.c4;
        matrix[3][0] = aiMatrix.d1;
        matrix[3][1] = aiMatrix.d2;
        matrix[3][2] = aiMatrix.d3;
        matrix[3][3] = aiMatrix.d4;

        return matrix;
    }

    void shutdown()
    {

    }

    shared struct AnimationSet
    {
        shared float duration;
        shared float fps;
        shared Node animNodes;
    }
    shared class Node
    {
        this( shared string nodeName )
        {
            name = nodeName;
        }

        shared string name;
        shared int id;
        shared Node parent;
        shared Node[] children;

        shared vec3[] positionKeys;
        shared quat[] rotationKeys;
        shared vec3[] scaleKeys;
        shared mat4 transform;
    }
}